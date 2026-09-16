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


def handle(client):
    upstream = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        upstream.connect(UPSTREAM)
    except OSError:
        client.close()
        return

    try:
        head, leftover = recv_headers(client)
        if not head:
            return

        is_create = bool(CREATE_RE.match(head))

        if is_create:
            # Small JSON body with Content-Length; buffer, rewrite, re-send.
            clen = parse_content_length(head)
            body = leftover
            if clen is not None:
                while len(body) < clen:
                    chunk = client.recv(65536)
                    if not chunk:
                        break
                    body += chunk
            new_body = rewrite_device_requests(body)
            if new_body != body:
                # Fix Content-Length to the rewritten body length.
                head = re.sub(
                    rb"(?i)content-length:\s*\d+",
                    b"Content-Length: %d" % len(new_body),
                    head,
                )
            upstream.sendall(head + new_body)
            # Relay the response (may be streamed) back to the client.
            pipe(upstream, client)
        else:
            # Transparent pass-through, preserving chunked bodies and streams.
            upstream.sendall(head + leftover)
            t = threading.Thread(target=pipe, args=(client, upstream), daemon=True)
            t.start()
            pipe(upstream, client)
            t.join(timeout=5)
    finally:
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
