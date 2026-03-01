#!/bin/bash

# Wait for pipewire to be ready
sleep 3

# Load XRDP module
pw-cli load-module libpipewire-module-xrdp args='{
    sink.stream.props = { node.name = xrdp-sink }
    sink.socket.path = /var/run/xrdp/1001/xrdp_chansrv_audio_out_socket_10
    source.socket.path = /var/run/xrdp/1001/xrdp_chansrv_audio_in_socket_10
}'
