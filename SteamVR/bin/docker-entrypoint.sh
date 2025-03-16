#!/bin/bash
set -x
# Add users
bash /usr/bin/create-users.sh
NV_VER=$(nvidia-smi --version | head -n 1 | awk '{ print $NF }')
# Clone Static Homedir
cd /tmp && wget https://download.nvidia.com/XFree86/Linux-x86_64/${NV_VER}/NVIDIA-Linux-x86_64-${NV_VER}.run && \
  chmod +x NVIDIA-Linux-x86_64-${NV_VER}.run && \
  ./NVIDIA-Linux-x86_64-${NV_VER}.run --silent --no-kernel-module && \
  rm NVIDIA-Linux-x86_64-${NV_VER}.run

#Very slow
#rsync -aHx /home/workspace /
cd /
su - $(id -un 1001) -c "zstdcat /home/workspace/workspace.tar.zst | tar --same-owner --overwrite xf -"
chown -R 1001:1001 /workspace
setcap CAP_SYS_NICE+ep /workspace/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher

# Add missing NixOS libraries and hope they're close!
#NV_VER=$(nvidia-smi --version | head -n 1 | awk '{ print $NF }' | grep -oE '^[0-9]+')
#sudo apt update
#sudo apt -y install libnvidia-gl-${NV_VER libnvidia-gl-${NV_VER}:i386}

# Add the ssh config if needed

if [ ! -f "/etc/ssh/sshd_config" ];
	then
		cp /ssh_orig/sshd_config /etc/ssh
fi

if [ ! -f "/etc/ssh/ssh_config" ];
	then
		cp /ssh_orig/ssh_config /etc/ssh
fi

if [ ! -f "/etc/ssh/moduli" ];
	then
		cp /ssh_orig/moduli /etc/ssh
fi

# generate fresh rsa key if needed
if [ ! -f "/etc/ssh/ssh_host_rsa_key" ];
	then
		ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
fi

# generate fresh dsa key if needed
if [ ! -f "/etc/ssh/ssh_host_dsa_key" ];
	then
		ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
fi

#prepare run dir
mkdir -p /var/run/sshd


# generate xrdp key
if [ ! -f "/etc/xrdp/rsakeys.ini" ];
	then
		xrdp-keygen xrdp auto
fi

# generate certificate for tls connection
if [ ! -f "/etc/xrdp/cert.pem" ];
	then
		# delete eventual leftover private key
		rm -f /etc/xrdp/key.pem || true
		cd /etc/xrdp
		if [ ! $CERTIFICATE_SUBJECT ]; then
			CERTIFICATE_SUBJECT="/C=US/ST=Some State/L=Some City/O=Some Org/OU=Some Unit/CN=Terminalserver"
		fi
		openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem -days 365 -subj "$CERTIFICATE_SUBJECT"
		crudini --set /etc/xrdp/xrdp.ini Globals security_layer tls
		crudini --set /etc/xrdp/xrdp.ini Globals certificate /etc/xrdp/cert.pem
		crudini --set /etc/xrdp/xrdp.ini Globals key_file /etc/xrdp/key.pem

fi

# generate machine-id
uuidgen > /etc/machine-id

# set keyboard for all sh users
echo "export QT_XKB_CONFIG_ROOT=/usr/share/X11/locale" >> /etc/profile

#chmod 777 /dev/input/by-id/*Microsoft*
#service dbus start

exec "$@"
