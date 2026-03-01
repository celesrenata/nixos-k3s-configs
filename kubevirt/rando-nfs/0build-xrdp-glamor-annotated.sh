#!/bin/bash
# Install Latest XRDP with XORGXRDP and GFX/Glamor server-side acceleration
# Tested on Ubuntu 22.04 LTS

BUILD_DIR=/tmp/xrdpbuild
echo "-> preparing $BUILD_DIR"
rm -f -r $BUILD_DIR
mkdir -p $BUILD_DIR


# Install Dependencies - Dev
echo "-> Installing dependencies..."
apt update
apt install -y git make autoconf libtool intltool pkg-config nasm xserver-xorg-dev libssl-dev libpam0g-dev libjpeg-dev libfuse-dev libopus-dev libmp3lame-dev libxfixes-dev libxrandr-dev libgbm-dev libepoxy-dev libegl1-mesa-dev libx264-dev

echo "-> Installing pulseaudio dependencies..."
apt install -y libcap-dev libsndfile-dev libsndfile1-dev libspeex-dev libpulse-dev

echo "-> Installing non-free dependencies..."
apt install -y libfdk-aac-dev

echo "-> Installing runtime dependencies..."
apt install pulseaudio
apt install xserver-xorg

echo "-> Cloning xrdp devel tip"
cd $BUILD_DIR
# We go straight to git tip here, so use with caution (you can grab the latest stable tag if you prefer)
git clone --branch devel --recursive https://github.com/neutrinolabs/xrdp.git
cd xrdp

echo "-> Building xrdp:"
./bootstrap
# Build with glamor explicitly enabled (does not appear to make a difference for core xrdp, but I kept this anyway)
./configure --enable-x264 --enable-glamor --enable-rfxcodec --enable-mp3lame --enable-fdkaac --enable-opus --enable-pixman --enable-fuse --enable-jpeg --enable-ipv6
# Control build statement (also works for me in Ubuntu 22.04, since it is xorgxrdp that actually links to glamor)
#./configure --enable-x264 --enable-rfxcodec --enable-mp3lame --enable-fdkaac --enable-opus --enable-pixman --enable-fuse --enable-jpeg --enable-ipv6
make -j4

echo "-> Installing xrdp:"
make install

echo "-> Core xrdp done."

echo "-> Cloning xorgxrdp from devel tip:"
cd $BUILD_DIR
git clone --branch devel --recursive https://github.com/neutrinolabs/xorgxrdp.git
cd xorgxrdp

echo "-> Building xorgxrdp:"
./bootstrap
./configure --enable-glamor
make -j4

echo "-> Installing xorgxrdp:"
make install

echo "-> xorgxrdp done."

echo "-> Enable any user to start the X server"
sudo sed -i 's/allowed-users=console/allowed-users=anybody/g' /etc/X11/Xwrapper.config

echo "-> enable service..."
systemctl enable xrdp
systemctl stop xrdp
systemctl start xrdp

exit

# -- I am NOT using the below, since I typically follow the Wiki instructions --


echo "-> Building pulseaudio plugin"
pulseaudio --version # Show installed version from here and use that version of pulseaudio

cd $BUILD_DIR
PULSEAUDIO_VERSION=$(pulseaudio --version | awk '{print $2}')
echo "-> we have pulseaudio $PULSEAUDIO_VERSION"
echo "-> downloading and unpacking source release..."
wget https://freedesktop.org/software/pulseaudio/releases/pulseaudio-$PULSEAUDIO_VERSION.tar.xz
tar xf pulseaudio-$PULSEAUDIO_VERSION.tar.xz
rm pulseaudio-$PULSEAUDIO_VERSION.tar.xz

echo "-> building pulseaudio:"
cd pulseaudio-$PULSEAUDIO_VERSION/
./configure --with-speex
PULSEAUDIO_SRC_DIR="$PWD"

echo "-> downloading pulseaudio-module..."
cd $BUILD_DIR
wget https://github.com/neutrinolabs/pulseaudio-module-xrdp/archive/v0.6.tar.gz -O pulseaudio-module-xrdp.tar.gz
tar xvzf pulseaudio-module-xrdp.tar.gz
rm pulseaudio-module-xrdp.tar.gz

echo "-> building pulseaudio-module:"
cd pulseaudio-module-xrdp*
./bootstrap
./configure PULSE_DIR=$PULSEAUDIO_SRC_DIR
make
make install

ls $(pkg-config --variable=modlibexecdir libpulse)

echo "-> cleaning up..."
cd /tmp
rm -f -r $BUILD_DIR

echo "-> cleaning up pulseaudio build dependencies..."
apt remove -y --purge libcap-dev libsndfile-dev libsndfile1-dev libspeex-dev libpulse-dev

echo "-> cleaning up non-free build dependencies..."
apt remove -y --purge libfdk-aac-dev

echo "-> cleaning up main build dependencies..."
apt remove -y --purge make autoconf libtool intltool pkg-config nasm xserver-xorg-dev libssl-dev libpam0g-dev libjpeg-dev libfuse-dev libopus-dev libmp3lame-dev libxfixes-dev libxrandr-dev libgbm-dev libepoxy-dev libegl1-mesa-dev

echo "-> autoremoving and clearing apt..."
apt autoremove -y
apt clean

echo "-> load audio module..."
systemctl stop xrdp
systemctl start xrdp

echo "-> misc. desktop fixes."
sudo apt install gnome-tweaks -y
# Permission weirdness fix
sudo bash -c "cat >/etc/polkit-1/localauthority/50-local.d/45-allow.colord.pkla" <<EOF
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF