FROM ubuntu:24.04 as builder
MAINTAINER Celes Hillyerd

ENV DEBIAN_FRONTEND noninteractive
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
RUN mkdir -p /etc/apt/apt.conf.d
RUN apt update
RUN apt -y install wget

RUN install -d -m 0755 /etc/apt/keyrings
# Mozilla PPA setup - FIXED: Uncommented and properly configured
RUN wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
RUN echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null
RUN apt-get -y update
RUN apt-get -yy upgrade
RUN apt -y remove firefox
RUN apt-get -y install software-properties-common
RUN add-apt-repository ppa:graphics-drivers/ppa -y
RUN add-apt-repository "deb http://archive.ubuntu.com/ubuntu noble-proposed multiverse" -y
RUN apt-get update

ENV BUILD_DEPS="git git-lfs autoconf automake libtool pkg-config libssl-dev libpam0g-dev \
    libx11-dev libxfixes-dev libxrandr-dev nasm xsltproc flex \
    bison libxml2-dev dpkg-dev libcap-dev libxkbfile-dev libfuse3-dev \
    xserver-xorg-dev libepoxy-dev xserver-xorg-core libpulse-dev libpulse0 \
    pulseaudio-utils pulseaudio-module-bluetooth libasound2-dev libfuse-dev"
RUN apt-get -yy install  sudo apt-utils software-properties-common $BUILD_DEPS

# Build XRDP from source for compatibility

WORKDIR /tmp
RUN apt-get source pipewire
RUN apt-get build-dep -yy pipewire
RUN cd $(find . -maxdepth 1 -type d -name "*pipewire*" | head -1) && dpkg-buildpackage -rfakeroot -uc -b
WORKDIR /tmp

# Remove existing XRDP packages to avoid conflicts
RUN apt remove -y xrdp xorgxrdp || true

# Install XRDP and development headers for xorgxrdp build
RUN apt install -y xrdp

# Build XRDP from source to get development headers
RUN apt-get install -y check
RUN apt-get source xrdp
RUN cd xrdp-* && dpkg-buildpackage -rfakeroot -uc -b
RUN dpkg -i xrdp-dev_*.deb || apt-get install -f -y

# Build tomlc99 (C TOML library) from source first
RUN git clone https://github.com/cktan/tomlc99.git
WORKDIR /tmp/tomlc99
RUN make && make install
# Build shared library manually if not created
RUN gcc -shared -fPIC -o libtoml.so.1.0 toml.o && \
    cp libtoml.so.1.0 /usr/local/lib/ && \
    ln -sf /usr/local/lib/libtoml.so.1.0 /usr/local/lib/libtoml.so.1 && \
    ln -sf /usr/local/lib/libtoml.so.1.0 /usr/local/lib/libtoml.so && \
    ldconfig
WORKDIR /tmp

WORKDIR /tmp

# Build PipeWire 1.4.7 for XRDP compatibility
RUN git clone https://gitlab.freedesktop.org/pipewire/pipewire.git -b 1.4.7
WORKDIR /tmp/pipewire
RUN meson setup builddir -Dprefix=/usr/local -Dlibpulse=enabled
RUN meson compile -C builddir
RUN meson install -C builddir

# Build WirePlumber (session manager for PipeWire)
WORKDIR /tmp
RUN git clone https://gitlab.freedesktop.org/pipewire/wireplumber.git -b 0.4.17
WORKDIR /tmp/wireplumber
RUN meson setup builddir -Dprefix=/usr/local
RUN meson compile -C builddir  
RUN meson install -C builddir

WORKDIR /tmp
ARG CACHE_BUST=438
# Clone upstream pipewire XRDP module
RUN git clone https://github.com/neutrinolabs/pipewire-module-xrdp.git && cd pipewire-module-xrdp && git log -1 --oneline
WORKDIR /tmp/pipewire-module-xrdp
# Build against our built PipeWire 1.4.7 with proper paths
RUN ./bootstrap && \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib/x86_64-linux-gnu/pkgconfig \
    CPPFLAGS="-I/usr/local/include" \
    LDFLAGS="-L/usr/local/lib -L/usr/local/lib/x86_64-linux-gnu" \
    ./configure
RUN make
RUN mkdir -p /tmp/so
RUN cp src/.libs/*.so /tmp/so

# Build XRDP with glamor support
WORKDIR /tmp
RUN git clone https://github.com/neutrinolabs/xrdp.git -b v0.9.24
WORKDIR /tmp/xrdp
RUN ./bootstrap && ./configure --enable-glamor && make && make install

# Build xorgxrdp v0.9.19 to match Ubuntu XRDP 0.9.24
WORKDIR /tmp
RUN git clone https://github.com/neutrinolabs/xorgxrdp.git -b v0.9.19
WORKDIR /tmp/xorgxrdp
RUN ./bootstrap && ./configure --enable-glamor && make && make install

WORKDIR /tmp
RUN git clone https://github.com/aristocratos/btop.git
WORKDIR /tmp/btop
RUN git checkout v1.3.2
RUN make 


FROM ubuntu:24.04
ENV TZ=America/Los_Angeles
ENV DEBIAN_FRONTEND noninteractive
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64
ARG ADDITIONAL_PACKAGES=""
ENV ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES}
RUN apt update && apt install -y software-properties-common apt-utils

RUN dpkg --add-architecture i386

RUN apt update
RUN add-apt-repository ppa:graphics-drivers/ppa -y && apt update
RUN apt -y full-upgrade && apt autoremove -y && rm -rf /var/cache/apt /var/lib/apt/lists

RUN apt-get update && apt-get install -y \
  antimicrox \
  bluetooth \
  ca-certificates \
  crudini \
  curl \
  kitty \
  kmod \
  less \
  locales && \
  apt autoremove -y && \
  rm -rf /var/cache/apt /var/lib/apt/lists

RUN apt-get update && apt-get install -y \
  nfs-common \
  openssh-server \
  software-properties-common \
  apt-transport-https \
  sudo \
  supervisor \
  uuid-runtime \
  vim \
  vlc \
  rsync \
  xauth \
  xautolock && \
  apt remove -y light-locker xscreensaver && \
  apt autoremove -y && \
  rm -rf /var/cache/apt /var/lib/apt/lists

RUN apt-get update && apt-get install -y \
  xfce4 && \
  apt autoremove -y && \
  rm -rf /var/cache/apt /var/lib/apt/lists

RUN apt-get update && apt-get install -y \
  xfce4-clipman-plugin \
  xfce4-cpugraph-plugin \
  xfce4-netload-plugin \
  xfce4-screenshooter && \
  apt autoremove -y && \
  rm -rf /var/cache/apt /var/lib/apt/lists

RUN apt-get update && apt-get install -y \
  xfce4-screensaver \
  xfce4-power-manager \
  xfce4-taskmanager \
  xfce4-terminal \
  xfce4-xkb-plugin && \
  apt autoremove -y && \
  rm -rf /var/cache/apt /var/lib/apt/lists

RUN apt-get update && apt-get install -y \
  xprintidle \
  zstd \
  $ADDITIONAL_PACKAGES && \
  apt autoremove -y && \
  rm -rf /var/cache/apt /var/lib/apt/lists && \
  mkdir -p /var/lib/xrdp-pipewire-installer
RUN apt-get update \
    && apt-get install -y mesa-utils libgl1-mesa-dri:amd64 libgl1-mesa-dri:i386 libgl1:i386 libgl1:amd64 libgl1:i386 libgtk-3-dev libgtkglext1-dev git git-lfs software-properties-common apt-utils steam-installer steam-devices dbus-x11 libc6:amd64 libc6:i386 libegl1:amd64 libegl1:i386 libgbm1:amd64 libgbm1:i386 libgl1-mesa-dri:amd64 libgl1-mesa-dri:i386 libgl1:amd64 libgl1:i386

# Install Ubuntu 24.04 native XRDP packages in runtime stage
RUN apt update && apt install -y xrdp

# Steam repository setup - temporarily disabled due to GPG issues
# RUN curl -s http://repo.steampowered.com/steam/archive/stable/steam.gpg | gpg --dearmor -o /usr/share/keyrings/steam.gpg > /dev/null
# RUN echo deb [arch=amd64 signed-by=/usr/share/keyrings/steam.gpg] http://repo.steampowered.com/steam/ stable steam | tee /etc/apt/sources.list.d/steam.list

# FIXED: Firefox PPA setup - proper order and configuration
# First, remove any existing Firefox installations and snap packages
RUN apt remove -y firefox firefox-esr && \
    snap remove firefox 2>/dev/null || true

# Install Sunshine from GitHub latest release
RUN SUNSHINE_VERSION=$(curl -s https://api.github.com/repos/LizardByte/Sunshine/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') && \
    curl -L "https://github.com/LizardByte/Sunshine/releases/download/${SUNSHINE_VERSION}/sunshine-ubuntu-24.04-amd64.deb" -o sunshine.deb && \
    apt-get install -y ./sunshine.deb && \
    rm sunshine.deb

# Install ALVR from GitHub latest release
RUN ALVR_VERSION=$(curl -s https://api.github.com/repos/alvr-org/ALVR/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') && \
    curl -L "https://github.com/alvr-org/ALVR/releases/download/${ALVR_VERSION}/alvr_streamer_linux.tar.gz" -o alvr.tar.gz && \
    tar -xzf alvr.tar.gz -C /opt/ && \
    ln -sf /opt/alvr_streamer_linux/bin/alvr_dashboard /usr/local/bin/alvr_dashboard && \
    rm alvr.tar.gz

# Copy scripts
COPY docker/scripts/install-nvidia-driver.sh /root/scripts/install-nvidia-driver.sh
COPY docker/scripts/xrdp-audio-bridge.py /usr/local/bin/xrdp-audio-bridge.py
RUN chmod +x /root/scripts/install-nvidia-driver.sh && chmod +x /usr/local/bin/xrdp-audio-bridge.py

# NVIDIA driver installation removed - using host drivers via nvidia runtime class

# Set up Mozilla PPA preferences BEFORE adding the PPA
COPY mozilla-firefox /etc/apt/preferences.d/mozilla-firefox

# Add Mozilla Team PPA
RUN add-apt-repository ppa:mozillateam/ppa -y

# Update package lists after adding PPA
RUN apt update

# Install Firefox from PPA with explicit preference
RUN apt install -y firefox --no-install-recommends

# Verify Firefox installation and create symlinks if needed
RUN which firefox || ln -sf /usr/bin/firefox /usr/local/bin/firefox

COPY --from=builder /tmp/btop/bin/btop /usr/bin/btop
COPY --from=builder /tmp/so/libpipewire-module-xrdp.so /var/lib/xrdp-pipewire-installer

# Copy built xorgxrdp modules with glamor support
COPY --from=builder /usr/lib/xorg/modules/ /usr/lib/xorg/modules/
RUN rm -rf /usr/lib/x86_64-linux-gnu/xrdp/*
COPY --from=builder /usr/lib/x86_64-linux-gnu/xrdp/ /usr/lib/x86_64-linux-gnu/xrdp/
# Copy custom XRDP binaries and libraries with glamor support
COPY --from=builder /usr/local/sbin/xrdp* /usr/local/sbin/
COPY --from=builder /usr/local/lib/xrdp/ /usr/lib/x86_64-linux-gnu/xrdp/

# Remove system PipeWire and use only built version
RUN apt remove -y pipewire pipewire-bin pipewire-pulse libpipewire-0.3-0t64 libpipewire-0.3-modules || true

# Copy built PipeWire from builder (complete replacement)
COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/lib/x86_64-linux-gnu/ /usr/local/lib/x86_64-linux-gnu/
COPY --from=builder /usr/local/bin/pipewire* /usr/local/bin/
COPY --from=builder /usr/local/bin/pw-* /usr/local/bin/
COPY --from=builder /usr/local/bin/wireplumber /usr/local/bin/
COPY --from=builder /usr/local/share/wireplumber/ /usr/local/share/wireplumber/
COPY --from=builder /usr/local/include/pipewire* /usr/local/include/
COPY --from=builder /usr/local/share/pipewire/ /usr/local/share/pipewire/

# Install PipeWire XRDP module
RUN mkdir -p /usr/local/lib/x86_64-linux-gnu/pipewire-0.3 && \
    cp /var/lib/xrdp-pipewire-installer/libpipewire-module-xrdp.so /usr/local/lib/x86_64-linux-gnu/pipewire-0.3/ && \
    ldconfig

# Ubuntu packages provide XRDP binaries and libraries
# Copy tomlc99 library from builder
COPY --from=builder /usr/local/lib/libtoml.so* /usr/local/lib/
# Ubuntu packages handle XRDP library setup
RUN ldconfig && \
    ln -sf /usr/local/lib/libtoml.so.1.0 /usr/local/lib/libtoml.so.1

# Copy XRDP configuration files and generate RSA keys
# Disable IPv6 and force IPv4 for XRDP
RUN echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf && \
    echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.conf

# Copy XRDP INI config with rdpsnd support  
COPY docker/config/xrdp.ini /etc/xrdp/xrdp.ini
COPY docker/config/sesman.ini /etc/xrdp/sesman.ini
# Install socket bridge and updated pipewire config
COPY docker/scripts/xrdp-socket-bridge.py /usr/local/bin/xrdp-socket-bridge.py
COPY docker/config/supervisor-xrdp-bridge.conf /etc/supervisor/conf.d/xrdp-bridge.conf
COPY docker/config/pipewire-minimal.conf /etc/pipewire.conf
RUN chmod +x /usr/local/bin/xrdp-socket-bridge.py
RUN echo 'startwm_start_cmd=/etc/xrdp/startwm.sh' >> /etc/xrdp/sesman.ini
# Fix socket directory permissions to prevent deletion
RUN mkdir -p /var/run/xrdp && chmod 755 /var/run/xrdp
# Create user socket directory for audio
RUN mkdir -p /var/run/xrdp/1001 && chmod 755 /var/run/xrdp/1001

RUN echo 'export XRDP_SOCKET_PATH=/var/run/xrdp/1001' >> /etc/xrdp/.Xsession && \
    echo 'export XRDP_PULSE_SINK_SOCKET=xrdp_chansrv_audio_out_socket_10' >> /etc/xrdp/.Xsession && \
    echo 'export XRDP_PULSE_SOURCE_SOCKET=xrdp_chansrv_audio_in_socket_10' >> /etc/xrdp/.Xsession
ARG XORG_CACHE_BUST=2
COPY  docker/config/xorg.conf /etc/X11/xrdp/xorg.conf
RUN mkdir -p /etc/xrdp /etc/X11/xrdp
# Ubuntu packages handle RSA key generation

# Ubuntu packages provide xorgxrdp modules
# Ubuntu packages provide rdpsnd support
ADD bin /usr/bin
ADD etc /etc
ADD autostart /etc/xdg/autostart
COPY docker/config/pipewire-minimal.conf /etc/pipewire.conf

# Add audio system supervisor config to ensure it always starts

# Configure
RUN mkdir -p /var/run/dbus && \
  cp /etc/X11/xrdp/xorg.conf /etc/X11 && \
  ln -sf /usr/lib/x86_64-linux-gnu/nvidia/xorg/nvidia_drv.so /usr/lib/xorg/modules/drivers/nvidia_drv.so && \
  groupadd -g 3 sys 2>/dev/null || true && \
  usermod -a -G sys root && \
  echo "blacklist i915" >> /etc/modprobe.d/blacklist-intel.conf && \
  echo "blacklist xe" >> /etc/modprobe.d/blacklist-intel.conf && \
  echo "blacklist nouveau" >> /etc/modprobe.d/blacklist-nouveau.conf && \
  apt remove -y xserver-xorg-video-nouveau || true && \
  sed -i "s/console/anybody/g" /etc/X11/Xwrapper.config && \
  if [ -f /etc/xrdp/sesman.ini ]; then sed -i "s/xrdp\/xorg/xorg/g" /etc/xrdp/sesman.ini; fi && \
  locale-gen en_US.UTF-8 && \
  echo 'export XDG_RUNTIME_DIR="/run/user/$UID"' > /etc/skel/.Xsession && \
  echo '# DISPLAY already set by startwm.sh' >> /etc/skel/.Xsession && \
  echo '# Clean up any existing audio processes and sockets' >> /etc/skel/.Xsession && \
  echo 'pkill -f pipewire 2>/dev/null || true' >> /etc/skel/.Xsession && \
  echo 'pkill -f pulseaudio 2>/dev/null || true' >> /etc/skel/.Xsession && \
  echo 'rm -rf /run/user/$UID/pulse 2>/dev/null || true' >> /etc/skel/.Xsession && \
  echo 'rm -f /run/user/$UID/pipewire-0.lock 2>/dev/null || true' >> /etc/skel/.Xsession && \
  echo 'mkdir -p /run/user/$UID' >> /etc/skel/.Xsession && \
  echo 'sleep 2' >> /etc/skel/.Xsession && \
  echo 'eval $(dbus-launch --sh-syntax)' >> /etc/skel/.Xsession && \
  echo 'echo "=== STARTING AUDIO SYSTEM ===" > /tmp/audio_startup.log' >> /etc/skel/.Xsession && \
  echo 'sleep 1' >> /etc/skel/.Xsession && \
  echo '/usr/local/bin/xrdp-audio-bridge.py > /tmp/audio_bridge.log 2>&1 &' >> /etc/skel/.Xsession && \
  echo 'PIPEWIRE_DEBUG=5 SPA_DEBUG=5 LD_LIBRARY_PATH=/usr/local/lib /usr/local/bin/pipewire --config /etc/pipewire.conf > /tmp/pipewire.log 2>&1 &' >> /etc/skel/.Xsession && \
  echo 'echo "=== PIPEWIRE STARTED ===" >> /tmp/audio_startup.log' >> /etc/skel/.Xsession && \
  echo 'sleep 1' >> /etc/skel/.Xsession && \
  echo 'PIPEWIRE_DEBUG=5 LD_LIBRARY_PATH=/usr/local/lib /usr/local/bin/pipewire-pulse > /tmp/pipewire-pulse.log 2>&1 &' >> /etc/skel/.Xsession && \
  echo 'echo "=== PIPEWIRE-PULSE STARTED ===" >> /tmp/audio_startup.log' >> /etc/skel/.Xsession && \
  echo 'sleep 5' >> /etc/skel/.Xsession && \
  echo 'WIREPLUMBER_DEBUG=5 LD_LIBRARY_PATH=/usr/local/lib /usr/local/bin/wireplumber > /tmp/wireplumber.log 2>&1 &' >> /etc/skel/.Xsession && \
  echo 'echo "=== WIREPLUMBER STARTED ===" >> /tmp/audio_startup.log' >> /etc/skel/.Xsession && \
  echo 'sleep 3' >> /etc/skel/.Xsession && \
  echo 'pw-cli load-module libpipewire-module-xrdp args='"'"'{ sink.stream.props = { node.name = xrdp-sink } sink.socket.path = /var/run/xrdp/1001/xrdp_chansrv_audio_out_socket_10 source.socket.path = /var/run/xrdp/1001/xrdp_chansrv_audio_in_socket_10 }'"'"' > /tmp/xrdp_module.log 2>&1 &' >> /etc/skel/.Xsession && \
  echo 'echo "=== XRDP MODULE LOADED ===" >> /tmp/audio_startup.log' >> /etc/skel/.Xsession && \
  echo 'sleep 2' >> /etc/skel/.Xsession && \
  echo 'echo "=== AUDIO SYSTEM READY ===" >> /tmp/audio_startup.log' >> /etc/skel/.Xsession && \
  echo 'xfce4-session' >> /etc/skel/.Xsession && \
  chmod +x /etc/skel/.Xsession && \
  # Backup simple .Xsession (working version): \
  echo '#!/bin/bash' > /etc/skel/.Xsession.simple && \
  echo 'export XDG_RUNTIME_DIR="/run/user/$UID"' >> /etc/skel/.Xsession.simple && \
  echo 'export HOME=/home/celes' >> /etc/skel/.Xsession.simple && \
  echo 'cd $HOME' >> /etc/skel/.Xsession.simple && \
  echo 'mkdir -p /run/user/$UID' >> /etc/skel/.Xsession.simple && \
  echo 'eval $(dbus-launch --sh-syntax)' >> /etc/skel/.Xsession.simple && \
  echo 'exec xfce4-session' >> /etc/skel/.Xsession.simple && \
  chmod +x /etc/skel/.Xsession.simple && \
  # Create PipeWire XRDP module loader script: \
  mkdir -p /usr/libexec/pipewire-module-xrdp && \
  echo '#!/bin/bash' > /usr/libexec/pipewire-module-xrdp/load_pw_modules.sh && \
  echo '# Load PipeWire XRDP module' >> /usr/libexec/pipewire-module-xrdp/load_pw_modules.sh && \
  echo 'pw-cli load-module libpipewire-module-xrdp' >> /usr/libexec/pipewire-module-xrdp/load_pw_modules.sh && \
  chmod +x /usr/libexec/pipewire-module-xrdp/load_pw_modules.sh && \
  # Fix critical system issues: \
  mkdir -p /run/dbus && \
  echo 'mkdir -p /run/dbus && dbus-daemon --system --fork' >> /etc/rc.local && \
  echo 'chown celes:celes /var/run/xrdp/1001 2>/dev/null || true' >> /etc/rc.local && \
  echo 'chmod 666 /dev/fb0 2>/dev/null || true' >> /etc/rc.local && \
  # Fix NVIDIA driver symbolic links for version compatibility: \
  echo 'cd /usr/lib/x86_64-linux-gnu && ln -sf libnvidia-ml.so.580.82.07 libnvidia-ml.so.1 && ln -sf libcuda.so.580.82.07 libcuda.so.1 && ln -sf libnvidia-opencl.so.580.82.07 libnvidia-opencl.so.1 && ln -sf libnvidia-ptxjitcompiler.so.580.82.07 libnvidia-ptxjitcompiler.so.1 && ln -sf libcudadebugger.so.580.82.07 libcudadebugger.so.1 && ln -sf libnvidia-nvvm.so.580.82.07 libnvidia-nvvm.so.4 && ln -sf libnvidia-cfg.so.580.82.07 libnvidia-cfg.so.1 && ln -sf libnvidia-allocator.so.580.82.07 libnvidia-allocator.so.1 && ldconfig' >> /etc/rc.local && \
  echo '#!/bin/bash' > /etc/xrdp/startwm.sh && \
  echo 'set -x' >> /etc/xrdp/startwm.sh && \
  echo 'exec > /tmp/startwm.log 2>&1' >> /etc/xrdp/startwm.sh && \
  echo 'echo "=== STARTWM DEBUG START ===" ' >> /etc/xrdp/startwm.sh && \
  echo 'echo "USER: $USER"' >> /etc/xrdp/startwm.sh && \
  echo 'echo "HOME: $HOME"' >> /etc/xrdp/startwm.sh && \
  echo 'echo "DISPLAY: $DISPLAY"' >> /etc/xrdp/startwm.sh && \
  echo 'echo "PWD: $(pwd)"' >> /etc/xrdp/startwm.sh && \
  echo 'export HOME=/home/celes' >> /etc/xrdp/startwm.sh && \
  echo 'cd $HOME' >> /etc/xrdp/startwm.sh && \
  echo 'echo "Changed to: $(pwd)"' >> /etc/xrdp/startwm.sh && \
  echo 'if [ -f $HOME/.Xsession ]; then' >> /etc/xrdp/startwm.sh && \
  echo '    echo "Found .Xsession, executing it"' >> /etc/xrdp/startwm.sh && \
  echo '    echo "Contents of .Xsession:"' >> /etc/xrdp/startwm.sh && \
  echo '    cat $HOME/.Xsession' >> /etc/xrdp/startwm.sh && \
  echo '    exec $HOME/.Xsession' >> /etc/xrdp/startwm.sh && \
  echo 'else' >> /etc/xrdp/startwm.sh && \
  echo '    echo "No .Xsession found, starting xfce4-session directly"' >> /etc/xrdp/startwm.sh && \
  echo '    which xfce4-session' >> /etc/xrdp/startwm.sh && \
  echo '    exec xfce4-session' >> /etc/xrdp/startwm.sh && \
  echo 'fi' >> /etc/xrdp/startwm.sh && \
  chmod +x /etc/xrdp/startwm.sh && \
  # Backup simple startwm.sh (working version): \
  echo '#!/bin/bash' > /etc/xrdp/startwm.sh.simple && \
  echo 'exec startxfce4' >> /etc/xrdp/startwm.sh.simple && \
  chmod +x /etc/xrdp/startwm.sh.simple && \
  cp -r /etc/ssh /ssh_orig && \
  rm -rf /etc/ssh/* && \
  rm -rf /etc/xrdp/rsakeys.ini /etc/xrdp/*.pem
# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8    
# font
RUN apt update && apt-get install fonts-droid-fallback ttf-wqy-zenhei ttf-wqy-microhei fonts-arphic-ukai fonts-arphic-uming -y
RUN apt update && apt install curl htop neofetch python3-pip python3-tk python-is-python3 libjpeg-dev p7zip-full gcc g++ fonts-noto-cjk-extra -y

# Install VirtualGL for GPU acceleration with XRDP
RUN wget https://sourceforge.net/projects/virtualgl/files/3.1.1/virtualgl_3.1.1_amd64.deb/download -O virtualgl.deb && \
    dpkg -i virtualgl.deb || apt-get install -f -y && \
    rm virtualgl.deb

#WORKDIR /tmp
#RUN apt -y install net-tools python-gi-dev cython3 libbluetooth-dev python3-cairo python3-networkmanager
#RUN git clone https://github.com/blueman-project/blueman
#WORKDIR /tmp/blueman
#RUN ./autogen.sh && make && make install

WORKDIR /tmp
RUN apt -y install blueman libldacbt-abr2 libldacbt-enc2 libspa-0.2-bluetooth pulseaudio-module-bluetooth- 

WORKDIR /workspace

# Add Firefox verification and debugging info
RUN echo "Firefox installation verification:" && \
    firefox --version && \
    which firefox && \
    ls -la /usr/bin/firefox* && \
    apt list --installed | grep firefox

# Docker config
VOLUME ["/etc/ssh","/home"]
EXPOSE 3389 22 9001
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["supervisord"]

