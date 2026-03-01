FROM ubuntu:22.04 as builder
MAINTAINER Celes Hillyerd

ENV DEBIAN_FRONTEND noninteractive
RUN sed -i "s/# deb-src/deb-src/g" /etc/apt/sources.list
RUN apt-get -y update
RUN apt-get -yy upgrade
ENV BUILD_DEPS="git autoconf pkg-config libssl-dev libpam0g-dev \
    libx11-dev libxfixes-dev libxrandr-dev nasm xsltproc flex \
    bison libxml2-dev dpkg-dev libcap-dev libxkbfile-dev"
RUN apt-get -yy install  sudo apt-utils software-properties-common $BUILD_DEPS

# Build XRDP

WORKDIR /tmp
RUN apt-get source pulseaudio
RUN apt-get build-dep -yy pulseaudio
RUN cd $(find . -maxdepth 1 -type d -name "*pulseaudio*" | head -1) && dpkg-buildpackage -rfakeroot -uc -b
WORKDIR /tmp
RUN git clone --branch devel --recursive https://github.com/neutrinolabs/xrdp.git
WORKDIR /tmp/xrdp
RUN ./bootstrap
RUN ./configure
RUN make
RUN make install
WORKDIR /tmp
RUN  apt -yy install libpulse-dev
RUN git clone --recursive https://github.com/neutrinolabs/pulseaudio-module-xrdp.git
WORKDIR /tmp/pulseaudio-module-xrdp
RUN ./bootstrap && ./configure PULSE_DIR=$(find /tmp -maxdepth 1 -type d -name "*pulseaudio*" | head -1)
RUN make
RUN mkdir -p /tmp/so
RUN cp src/.libs/*.so /tmp/so

WORKDIR /tmp
RUN git clone https://github.com/aristocratos/btop.git
WORKDIR /tmp/btop
RUN gmake PREFIX=/usr && gmake install && gmake setuid


FROM nvidia/cuda:12.5.0-runtime-ubuntu22.04
ENV TZ=America/Los_Angeles
ENV DEBIAN_FRONTEND noninteractive
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null
ARG ADDITIONAL_PACKAGES=""
ENV ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES}
RUN apt update && apt install -y software-properties-common apt-utils
RUN add-apt-repository "deb http://archive.canonical.com/ $(lsb_release -sc) partner"e
COPY mozilla-firefox /etc/apt/preferences.d/mozilla-firefox
RUN add-apt-repository ppa:mozillateam/ppa && apt update

RUN apt -y full-upgrade && apt-get install -y \
  ca-certificates \
  crudini \
  firefox \
  kitty \
  less \
  locales \
  openssh-server \
  pulseaudio \
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
  mkdir -p /var/lib/xrdp-pulseaudio-installer
COPY --from=builder /tmp/so/module-xrdp-source.so /var/lib/xrdp-pulseaudio-installer
COPY --from=builder /tmp/so/module-xrdp-sink.so /var/lib/xrdp-pulseaudio-installer
ADD bin /usr/bin
ADD etc /etc
ADD autostart /etc/xdg/autostart

# Configure
RUN mkdir /var/run/dbus && \
  cp /etc/X11/xrdp/xorg.conf /etc/X11 && \
  sed -i "s/console/anybody/g" /etc/X11/Xwrapper.config && \
  sed -i "s/xrdp\/xorg/xorg/g" /etc/xrdp/sesman.ini && \
  locale-gen en_US.UTF-8 && \
  echo "pulseaudio -D --enable-memfd=True" > /etc/skel/.Xsession && \
  echo "xfce4-session" >> /etc/skel/.Xsession && \
  cp -r /etc/ssh /ssh_orig && \
  rm -rf /etc/ssh/* && \
  rm -rf /etc/xrdp/rsakeys.ini /etc/xrdp/*.pem

# font
RUN apt update && apt-get install fonts-droid-fallback ttf-wqy-zenhei ttf-wqy-microhei fonts-arphic-ukai fonts-arphic-uming -y
RUN apt update && apt install curl htop neofetch python3-pip python3-tk python-is-python3 libjpeg-dev p7zip-full gcc g++ fonts-noto-cjk-extra -y

WORKDIR /workspace

#RUN curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba

# python
RUN apt-get update \
    && apt-get install -y mesa-utils libgl1-mesa-dri libgtkgl2.0-dev libgtkglext1-dev git software-properties-common apt-utils \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt install -y python3.10 python3.10-distutils curl \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10
RUN apt-get install -y python3.10-dev python3.10-venv
# clone OneTrainer
#RUN pip install torch==2.5.1+cu124 --extra-index-url https://download.pytorch.org/whl/cu124
#RUN pip install torchvision==0.20.1+cu124 --extra-index-url https://download.pytorch.org/whl/cu124
#RUN pip install onnxruntime-gpu==1.19.2
RUN git clone https://github.com/Nerogar/OneTrainer.git
#    && pip install -r OneTrainer/requirements-cuda.txt 
#RUN pip install -r OneTrainer/requirements-global.txt

#RUN apt install --yes --no-install-recommends nvidia-container-toolkit

# RUN
ENV PYTHON=python3.10
ENV ONETRAINER_PATH=/workspace/OneTrainer
ENV PATH="$PATH:$ONETRAINER_PATH"
WORKDIR $ONETRAINER_PATH


# Docker config
VOLUME ["/etc/ssh","/home"]
EXPOSE 3389 22 9001
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["supervisord"]

