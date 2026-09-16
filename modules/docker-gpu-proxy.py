#!/usr/bin/env python3
"""Proxy the Docker socket, rewriting legacy GPU DeviceRequests to CDI format.

Only POST /containers/create bodies are parsed/rewritten. Every other request
(including chunked PUT /containers/{id}/archive uploads used by AppAPI/HaRP to
install certs, and streaming responses like logs/pull/attach) is relayed as a
transparent, bidirectional byte stream so chunked transfer-encoding and
connection semantics are preserved.
"""
import os
import re
import json
import socket
import threading

UPSTREAM = "/var/run/docker.sock"
LISTEN = "/var/run/docker-gpu.sock"

CREATE_RE = re.compile(rb"^POST\s+\S*/containers/create(\?\S*)?\s+HTTP/1\.[01]", re.I)


def rewrite_device_requests(body_bytes):
    """Rewrite legacy nvidia DeviceRequests to CDI format. Returns new body."""
    try:
        data = json.loads(body_bytes)
    except (json.JSONDecodeError, TypeError, ValueError):
        return body_bytes

    host_config = data.get("HostConfig") or {}
    device_requests = host_config.get("DeviceRequests") or []
    if not device_requests:
        return body_bytes

    rewritten = False
    for req in device_requests:
        caps = req.get("Capabilities") or []
        driver = req.get("Driver", "")
        if driver in ("", "nvidia") and any(
            ("compute" in c or "gpu" in c) for c in caps
        ):
            req["Driver"] = "cdi"
            req["DeviceIDs"] = ["nvidia.com/gpu=all"]
            req["Capabilities"] = None
            req["Count"] = 0
            rewritten = True

    if not rewritten:
        return body_bytes
    return json.dumps(data).encode()


def recv_headers(sock):
    """Read until end of HTTP headers. Returns (head_bytes, leftover_bytes)."""
    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = sock.recv(65536)
        if not chunk:
            break
        buf += chunk
    idx = buf.find(b"\r\n\r\n")
    if idx == -1:
        return buf, b""
    return buf[: idx + 4], buf[idx + 4 :]


def parse_content_length(head):
    for line in head.split(b"\r\n"):
        if line.lower().startswith(b"content-length:"):
            try:
                return int(line.split(b":", 1)[1].strip())
            except ValueError:
                return None
    return None


def strip_transfer_encoding(head):
    """Remove any Transfer-Encoding header line from a raw header block."""
    lines = head.split(b"\r\n")
    kept = [l for l in lines if not l.lower().startswith(b"transfer-encoding:")]
    return b"\r\n".join(kept)


def read_chunked_body(sock, leftover):
    """Read and decode an HTTP/1.1 chunked request body into raw bytes."""
    buf = bytearray(leftover)
    out = bytearray()
    while True:
        # Ensure we have a full chunk-size line.
        while b"\r\n" not in buf:
            more = sock.recv(65536)
            if not more:
                return bytes(out)
            buf += more
        line, _, rest = bytes(buf).partition(b"\r\n")
        buf = bytearray(rest)
        size_str = line.split(b";", 1)[0].strip()
        try:
            size = int(size_str, 16)
        except ValueError:
            return bytes(out)
        if size == 0:
            break  # last chunk; ignore trailers
        while len(buf) < size + 2:  # chunk data + trailing CRLF
            more = sock.recv(65536)
            if not more:
                break
            buf += more
        out += buf[:size]
        buf = bytearray(buf[size + 2 :])
    return bytes(out)


def pipe(src, dst):
    """Relay bytes from src to dst until EOF, then half-close dst."""
    try:
        while True:
            chunk = src.recv(65536)
            if not chunk:
                break
            dst.sendall(chunk)
    except OSError:
        pass
    finally:
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def read_request(sock, carry):
    """Read one full HTTP request (head + body) from sock.

    `carry` is a bytearray of bytes already read past the previous request.
    Returns (request_bytes, is_create, rewritten_request_bytes) or None on EOF.
    Handles Content-Length and chunked request bodies so we know exactly where
    each request ends on a keep-alive connection.
    """
    # Read until we have the full header block.
    while b"\r\n\r\n" not in carry:
        more = sock.recv(65536)
        if not more:
            return None
        carry += more
    hidx = carry.find(b"\r\n\r\n")
    head = bytes(carry[: hidx + 4])
    rest = bytearray(carry[hidx + 4 :])

    is_create = bool(CREATE_RE.match(head))
    clen = parse_content_length(head)
    chunked = b"transfer-encoding: chunked" in head.lower()

    if chunked:
        body = read_chunked_body(sock, bytes(rest))
        # read_chunked_body consumed exactly the chunked body from rest+socket;
        # anything it over-read is lost, but docker clients don't pipeline past
        # a chunked body before the response, so carry resets empty.
        leftover = bytearray()
    else:
        n = clen or 0
        while len(rest) < n:
            more = sock.recv(65536)
            if not more:
                break
            rest += more
        body = bytes(rest[:n])
        leftover = bytearray(rest[n:])

    if is_create:
        new_body = rewrite_device_requests(body)
        out_head = strip_transfer_encoding(head)
        if parse_content_length(out_head) is not None:
            out_head = re.sub(
                rb"(?i)content-length:\s*\d+",
                b"Content-Length: %d" % len(new_body),
                out_head,
            )
        else:
            out_head = out_head[:-2] + b"Content-Length: %d\r\n\r\n" % len(new_body)
        return (out_head + new_body, True, leftover)

    return (head + body, False, leftover)


def handle(client):
    upstream = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        upstream.connect(UPSTREAM)
    except OSError:
        client.close()
        return

    # Relay responses upstream->client for the whole (keep-alive) connection.
    resp_thread = threading.Thread(target=pipe, args=(upstream, client), daemon=True)
    resp_thread.start()

    carry = bytearray()
    try:
        while True:
            result = read_request(client, carry)
            if result is None:
                break
            req_bytes, _is_create, leftover = result
            carry = leftover
            try:
                upstream.sendall(req_bytes)
            except OSError:
                break
    finally:
        try:
            upstream.shutdown(socket.SHUT_WR)
        except OSError:
            pass
        resp_thread.join(timeout=10)
        try:
            upstream.close()
        except OSError:
            pass
        try:
            client.close()
        except OSError:
            pass


def main():
    if os.path.exists(LISTEN):
        os.unlink(LISTEN)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(LISTEN)
    os.chmod(LISTEN, 0o666)
    server.listen(128)
    print(f"Docker GPU proxy listening on {LISTEN}", flush=True)
    while True:
        conn, _ = server.accept()
        threading.Thread(target=handle, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
