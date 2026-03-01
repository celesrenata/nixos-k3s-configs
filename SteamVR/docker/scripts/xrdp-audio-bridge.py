#!/usr/bin/env python3
import os
import socket
import threading
import time
import stat

def create_fifo_if_needed(fifo_path):
    """Create FIFO if it doesn't exist"""
    if not os.path.exists(fifo_path):
        os.mkfifo(fifo_path, 0o666)
        print(f"Created FIFO: {fifo_path}")

def bridge_socket_to_fifo(socket_path, fifo_path):
    """Bridge Unix socket to FIFO"""
    create_fifo_if_needed(fifo_path)
    
    while True:
        try:
            # Wait for socket to exist
            if not os.path.exists(socket_path):
                time.sleep(0.1)
                continue
                
            # Connect to Unix socket
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(socket_path)
            print(f"Connected to socket: {socket_path}")
            
            # Open FIFO for writing
            with open(fifo_path, 'wb') as fifo:
                print(f"Opened FIFO: {fifo_path}")
                
                while True:
                    data = sock.recv(4096)
                    if not data:
                        break
                    fifo.write(data)
                    fifo.flush()
                    
        except Exception as e:
            print(f"Bridge error: {e}")
            time.sleep(1)
        finally:
            try:
                sock.close()
            except:
                pass

def main():
    uid = os.getuid()
    socket_dir = f"/var/run/xrdp/{uid}"
    
    # Audio output bridge
    out_socket = f"{socket_dir}/xrdp_chansrv_audio_out_socket_10"
    out_fifo = f"{socket_dir}/xrdp_audio_out_fifo_10"
    
    # Audio input bridge  
    in_socket = f"{socket_dir}/xrdp_chansrv_audio_in_socket_10"
    in_fifo = f"{socket_dir}/xrdp_audio_in_fifo_10"
    
    print(f"Starting XRDP audio bridge for UID {uid}")
    
    # Start bridge threads
    threading.Thread(target=bridge_socket_to_fifo, args=(out_socket, out_fifo), daemon=True).start()
    threading.Thread(target=bridge_socket_to_fifo, args=(in_socket, in_fifo), daemon=True).start()
    
    # Keep running
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Bridge stopped")

if __name__ == "__main__":
    main()
