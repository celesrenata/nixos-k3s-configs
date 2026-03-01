#!/usr/bin/env python3
import socket
import os
import threading
import time
import sys

def bridge_sockets():
    chansrv_socket_path = "/var/run/xrdp/1001/xrdp_chansrv_audio_out_socket_10"
    bridge_socket_path = "/var/run/xrdp/1001/xrdp_audio_bridge_socket_10"
    
    print("Waiting for XRDP session directory to be created...")
    
    # Wait for the directory to exist (created by XRDP session)
    while not os.path.exists(os.path.dirname(bridge_socket_path)):
        time.sleep(5)
        print("Still waiting for /var/run/xrdp/1001/ directory...")
    
    print(f"Directory exists, setting up bridge...")
    
    # Remove old bridge socket
    try:
        os.unlink(bridge_socket_path)
    except:
        pass
    
    # Create bridge socket
    bridge_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    bridge_sock.bind(bridge_socket_path)
    os.chmod(bridge_socket_path, 0o666)
    bridge_sock.listen(1)
    
    print(f"Bridge listening on {bridge_socket_path}")
    
    while True:
        try:
            # Wait for pipewire connection
            client_sock, addr = bridge_sock.accept()
            print("Pipewire connected to bridge")
            
            # Connect to chansrv
            chansrv_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            chansrv_sock.connect(chansrv_socket_path)
            print("Bridge connected to chansrv")
            
            # Bridge data in both directions
            def forward(src, dst, name):
                try:
                    while True:
                        data = src.recv(4096)
                        if not data:
                            break
                        dst.send(data)
                except:
                    pass
                finally:
                    src.close()
                    dst.close()
            
            threading.Thread(target=forward, args=(client_sock, chansrv_sock, "client->chansrv")).start()
            threading.Thread(target=forward, args=(chansrv_sock, client_sock, "chansrv->client")).start()
            
        except Exception as e:
            print(f"Bridge error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    bridge_sockets()
