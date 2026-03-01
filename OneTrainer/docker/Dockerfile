FROM ubuntu:24.04 as builder
MAINTAINER Celes Hillyerd

ENV DEBIAN_FRONTEND noninteractive
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
RUN apt-get -y update
RUN apt-get -yy upgrade
ENV BUILD_DEPS="git autoconf pkg-config libssl-dev libpam0g-dev \
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
RUN ./bootstrap && ./configure PULSE_DIR=$(find /tmp -maxdepth 1 -type d -name "*pipewire*" | head -1)
RUN make
RUN mkdir -p /tmp/so
RUN cp src/.libs/*.so /tmp/so

WORKDIR /tmp
RUN apt-get install -y g++-14
RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 100
RUN git clone https://github.com/aristocratos/btop.git
WORKDIR /tmp/btop
RUN gmake PREFIX=/usr


FROM nvidia/cuda:12.6.3-runtime-ubuntu24.04
ENV TZ=America/Los_Angeles
ENV DEBIAN_FRONTEND noninteractive
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null
ARG ADDITIONAL_PACKAGES=""
ENV ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES}
RUN apt update && apt install -y software-properties-common apt-utils
RUN add-apt-repository ppa:mozillateam/ppa && apt update
COPY mozilla-firefox /etc/apt/preferences.d/mozilla-firefox
RUN apt -y full-upgrade && apt-get install -y \
  ca-certificates \
  crudini \
  dbus-x11 \
  firefox \
  kitty \
  less \
  locales \
  openssh-server \
  pipewire \
  sudo \
  supervisor \
  uuid-runtime \
  vim \
  vlc \
  rsync \
  wget \
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
  nvidia-cuda-toolkit \
  $ADDITIONAL_PACKAGES && \
  apt remove -y light-locker xscreensaver && \
  apt autoremove -y && \
  rm -rf /var/cache/apt /var/lib/apt/lists && \
  mkdir -p /var/lib/xrdp-pipewire-installer
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
  echo ". /usr/local/bin/run-pipewire" > /etc/skel/.Xsession && \
  echo "xfce4-session" >> /etc/skel/.Xsession && \
  cp -r /etc/ssh /ssh_orig && \
  rm -rf /etc/ssh/* && \
  rm -rf /etc/xrdp/rsakeys.ini /etc/xrdp/*.pem
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# font
RUN apt update && apt-get install fonts-droid-fallback ttf-wqy-zenhei ttf-wqy-microhei fonts-arphic-ukai fonts-arphic-uming -y
RUN apt update && apt install curl htop neofetch python3-pip python3-tk python-is-python3 libjpeg-dev p7zip-full gcc g++ fonts-noto-cjk-extra -y

WORKDIR /workspace

#RUN curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba

# python
RUN apt-get update \
    && apt-get install -y mesa-utils libgl1-mesa-dri libgtk2.0-dev libgtkglext1-dev git software-properties-common apt-utils \
    && apt-get update \
    && apt install -y python3.12 python3-pip python3-setuptools curl
#    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12
RUN apt-get install -y python3.12-dev python3.12-venv
# clone OneTrainer to template location
RUN git clone https://github.com/Nerogar/OneTrainer.git /opt/OneTrainer-template

# Create init script to copy OneTrainer on startup
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Updating OneTrainer..."\n\
rm -rf /workspace/OneTrainer 2>/dev/null || true\n\
cp -r /opt/OneTrainer-template /workspace/OneTrainer\n\
echo "OneTrainer updated"\n' > /usr/bin/init-onetrainer.sh && chmod +x /usr/bin/init-onetrainer.sh

ENV PYTHON=python3.12
ENV ONETRAINER_PATH=/workspace/OneTrainer
ENV PATH="$PATH:$ONETRAINER_PATH"
WORKDIR /workspace


# Docker config
VOLUME ["/etc/ssh","/home"]
EXPOSE 3389 22 9001
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["supervisord"]

