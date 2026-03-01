#!/bin/bash

echo "=== Creating users from auth mechanism ==="

# Process /root/createusers.txt for auth system
if [ -f /root/createusers.txt ]; then
    echo "Processing /root/createusers.txt..."
    while IFS=: read -r username password is_sudo; do
        # Skip empty lines and comments
        [[ -z "$username" || "$username" =~ ^#.*$ ]] && continue
        
        echo "Creating auth user: $username (sudo: $is_sudo)"
        
        # Check if user already exists
        if id "$username" &>/dev/null; then
            echo "User $username already exists, updating password and settings..."
        else
            # Create user with home directory and UID 1001
            useradd -m -u 1001 -s /bin/bash "$username"
            echo "User $username created with UID 1001"
        fi
        
        # Set password (plain text)
        echo "$username:$password" | chpasswd
        echo "Password set for $username"
        
        # Add to sudo group if requested
        if [ "$is_sudo" = "Y" ] || [ "$is_sudo" = "y" ]; then
            usermod -aG sudo "$username"
            echo "$username added to sudo group"
            
            # Allow passwordless sudo for convenience
            echo "$username ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$username"
            chmod 440 "/etc/sudoers.d/$username"
        fi
        
        # Add to essential groups (including sys for /dev/tty0 access)
        usermod -aG audio,video,input,dialout,plugdev,sys "$username"
        
        # Create runtime directory
        USER_ID=$(id -u "$username")
        mkdir -p "/run/user/$USER_ID"
        chown "$username:$username" "/run/user/$USER_ID"
        chmod 700 "/run/user/$USER_ID"
        
        # Set up workspace permissions
        if [ -d /workspace ]; then
            chown -R "$username:$username" /workspace
            chmod -R 755 /workspace
            
            # Ensure games directory has full permissions
            if [ -d /workspace/games ]; then
                chown -R "$username:$username" /workspace/games
                chmod -R 755 /workspace/games
                # Make executables runnable
                find /workspace/games -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
                find /workspace/games -type f -name "*.exe" -exec chmod +x {} \; 2>/dev/null || true
            fi
        fi
        
        # Create .Xclients and .xsession for desktop session with PipeWire
        echo "#!/bin/bash" > "/home/$username/.Xclients"
        echo "export DBUS_SYSTEM_BUS_ADDRESS=\"unix:path=/run/user/$USER_ID/pw-dbus-session\"" >> "/home/$username/.Xclients"
        echo "export XDG_RUNTIME_DIR=\"/run/user/$USER_ID\"" >> "/home/$username/.Xclients"
        echo "dbus-daemon --session --address=\$DBUS_SYSTEM_BUS_ADDRESS &" >> "/home/$username/.Xclients"
        echo "sleep 0.5" >> "/home/$username/.Xclients"
        echo "pipewire --config /usr/share/pipewire/pipewire.conf &" >> "/home/$username/.Xclients"
        echo "sleep 0.5" >> "/home/$username/.Xclients"
        echo "pipewire-pulse &" >> "/home/$username/.Xclients"
        echo "sleep 0.5" >> "/home/$username/.Xclients"
        echo "wireplumber &" >> "/home/$username/.Xclients"
        echo "sleep 0.5" >> "/home/$username/.Xclients"
        echo "# Set XRDP audio socket environment variables" >> "/home/$username/.Xclients"
        echo "export XRDP_PULSE_SINK_SOCKET=/var/run/xrdp/$USER_ID/xrdp_chansrv_audio_out_socket_10" >> "/home/$username/.Xclients"
        echo "export XRDP_PULSE_SOURCE_SOCKET=/var/run/xrdp/$USER_ID/xrdp_chansrv_audio_in_socket_10" >> "/home/$username/.Xclients"
        echo "# Fix XRDP audio socket permissions" >> "/home/$username/.Xclients"
        echo "chmod 666 /var/run/xrdp/$USER_ID/xrdp_chansrv_audio_*_socket_* 2>/dev/null || true" >> "/home/$username/.Xclients"
        echo "pw-cli load-module libpipewire-module-xrdp &" >> "/home/$username/.Xclients"
        echo "sleep 0.5" >> "/home/$username/.Xclients"
        echo "exec startxfce4" >> "/home/$username/.Xclients"
        
        cp "/home/$username/.Xclients" "/home/$username/.xsession"
        chown "$username:$username" "/home/$username/.Xclients" "/home/$username/.xsession"
        chmod +x "/home/$username/.Xclients" "/home/$username/.xsession"
        
        echo "User $username setup complete"
        
    done < /root/createusers.txt
else
    echo "No /root/createusers.txt found - no users will be created"
fi

echo "=== User creation complete ==="
