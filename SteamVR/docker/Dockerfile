FROM ubuntu:24.04 as builder
MAINTAINER Celes Hillyerd

ENV DEBIAN_FRONTEND noninteractive
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
RUN mkdir -p /etc/apt/apt.conf.d
RUN apt update
RUN apt -y install wget

RUN install -d -m 0755 /etc/apt/keyrings
#RUN wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
#RUN echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null
RUN apt-get -y update
RUN apt-get -yy upgrade
RUN apt -y remove firefox

ENV BUILD_DEPS="git git-lfs autoconf pkg-config libssl-dev libpam0g-dev \
    libx11-dev libxfixes-dev libxrandr-dev nasm xsltproc flex \
    bison libxml2-dev dpkg-dev libcap-dev libxkbfile-dev"
RUN apt-get -yy install  sudo apt-utils software-properties-common $BUILD_DEPS

# Build XRDP

WORKDIR /tmp
RUN apt-get source pipewire
RUN apt-get build-dep -yy pipewire
RUN cd $(find . -maxdepth 1 -type d -name "*pipewire*" | head -1) && dpkg-buildpackage -rfakeroot -uc -b
WORKDIR /tmp
RUN git clone --branch devel --recursive https://github.com/neutrinolabs/xrdp.git
WORKDIR /tmp/xrdp
RUN ./bootstrap
RUN ./configure
RUN make
RUN make install
WORKDIR /tmp
RUN  apt -yy install libpipewire-0.3-dev
RUN git clone --recursive https://github.com/neutrinolabs/pipewire-module-xrdp.git
WORKDIR /tmp/pipewire-module-xrdp
RUN ./bootstrap && ./configure PIPEWIRE_DIR=$(find /tmp -maxdepth 1 -type d -name "*pipewire*" | head -1)
RUN make
RUN mkdir -p /tmp/so
RUN cp src/.libs/*.so /tmp/so

WORKDIR /tmp
RUN git clone https://github.com/aristocratos/btop.git
WORKDIR /tmp/btop
RUN gmake PREFIX=/usr 


FROM nvidia/cuda:12.6.0-runtime-ubuntu24.04
ENV TZ=America/Los_Angeles
ENV DEBIAN_FRONTEND noninteractive
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null
ARG ADDITIONAL_PACKAGES=""
ENV ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES}
RUN apt update && apt install -y software-properties-common apt-utils

RUN dpkg --add-architecture i386

RUN apt update
RUN apt -y full-upgrade && apt-get install -y \
  antimicrox \
  bluetooth \
  ca-certificates \
  crudini \
  curl \
  kitty \
  kmod \
  less \
  locales \
  nvidia-prime \
  openssh-server \
  pipewire \
  software-properties-common \
  apt-transport-https \
  sudo \
  supervisor \
  uuid-runtime \
  vim \
  vlc \
  rsync \
  xauth \
  xautolock \
  xfce4 \
  xfce4-clipman-plugin \
  xfce4-cpugraph-plugin \
  xfce4-netload-plugin \
  xfce4-screenshooter \
  xfce4-screensaver \
  xfce4-power-manager \
  xfce4-taskmanager \
  xfce4-terminal \
  xfce4-xkb-plugin \
  xorgxrdp \
  xprintidle \
  xrdp \
  zstd \
  nvidia-cuda-toolkit \
  $ADDITIONAL_PACKAGES && \
  apt remove -y light-locker xscreensaver && \
  apt autoremove -y && \
  rm -rf /var/cache/apt /var/lib/apt/lists && \
  mkdir -p /var/lib/xrdp-pipewire-installer
RUN apt-get update \
    && apt-get install -y mesa-utils libgl1-mesa-dri:amd64 libgl1-mesa-dri:i386 libgl1:i386 libgl1:amd64 libgl1:i386 libgtk-3-dev libgtkglext1-dev git git-lfs software-properties-common apt-utils steam-installer steam-devices dbus-x11 libc6:amd64 libc6:i386 libegl1:amd64 libegl1:i386 libgbm1:amd64 libgbm1:i386 libgl1-mesa-dri:amd64 libgl1-mesa-dri:i386 libgl1:amd64 libgl1:i386

RUN curl -s http://repo.steampowered.com/steam/archive/stable/steam.gpg | gpg --dearmor -o /usr/share/keyrings/steam.gpg > /dev/null
RUN echo deb [arch=amd64 signed-by=/usr/share/keyrings/steam.gpg] http://repo.steampowered.com/steam/ stable steam | tee /etc/apt/sources.list.d/steam.list
COPY mozilla-firefox /etc/apt/preferences.d/mozilla-firefox
RUN add-apt-repository ppa:mozillateam/ppa
RUN apt update
RUN apt -y install firefox
COPY --from=builder /tmp/btop/bin/btop /usr/bin/btop
COPY --from=builder /tmp/so/libpipewire-module-xrdp.so /var/lib/xrdp-pipewire-installer
ADD bin /usr/bin
ADD etc /etc
ADD autostart /etc/xdg/autostart

# Configure
RUN mkdir -p /var/run/dbus && \
  cp /etc/X11/xrdp/xorg.conf /etc/X11 && \
  sed -i "s/console/anybody/g" /etc/X11/Xwrapper.config && \
  sed -i "s/xrdp\/xorg/xorg/g" /etc/xrdp/sesman.ini && \
  locale-gen en_US.UTF-8 && \
  echo 'export DBUS_SYSTEM_BUS_ADDRESS="unix:path=/run/user/$UID/pw-dbus-session"' > /etc/skel/.Xsession && \
  echo 'export XDG_RUNTIME_DIR="/run/user/$UID"' >> /etc/skel/.Xsession && \
  echo 'dbus-daemon --session --address=$DBUS_SYSTEM_BUS_ADDRESS &' >> /etc/skel/.Xsession && \
  echo 'sleep 0.5' >> /etc/skel/.Xsession && \
  echo 'pipewire --config /usr/share/pipewire/pipewire.conf &' >> /etc/skel/.Xsession && \
  echo 'sleep 0.5' >> /etc/skel/.Xsession && \
  echo 'pipewire-pulse &' >> /etc/skel/.Xsession && \
  echo 'sleep 0.5' >> /etc/skel/.Xsession && \
  echo 'wireplumber &' >> /etc/skel/.Xsession && \
  echo 'sleep 0.5' >> /etc/skel/.Xsession && \
  echo 'xfce4-session' >> /etc/skel/.Xsession && \
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

#WORKDIR /tmp
#RUN apt -y install net-tools python-gi-dev cython3 libbluetooth-dev python3-cairo python3-networkmanager
#RUN git clone https://github.com/blueman-project/blueman
#WORKDIR /tmp/blueman
#RUN ./autogen.sh && make && make install

WORKDIR /tmp
RUN apt -y install blueman libldacbt-abr2 libldacbt-enc2 libspa-0.2-bluetooth pulseaudio-module-bluetooth- 

WORKDIR /workspace


# Docker config
VOLUME ["/etc/ssh","/home"]
EXPOSE 3389 22 9001
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["supervisord"]

