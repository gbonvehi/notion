# http://blog.csicar.de/docker/window-manger/2016/05/24/docker-wm.html
# docker build . -t notion
# Xephyr :1 -ac -br -screen 1024x768 -resizeable -reset -terminate &
# docker run -it -e DISPLAY=:1 -v /tmp/.X11-unix:/tmp/.X11-unix notion

# docker build . -t notion && docker run -it -e DISPLAY=:1 -v /tmp/.X11-unix:/tmp/.X11-unix --entrypoint /bin/bash notion

FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive
RUN echo 'Acquire::http { Proxy "http://172.17.0.1:3142"; };' >> /etc/apt/apt.conf.d/01proxy
RUN apt update && apt install -y pkg-config build-essential
# TMP
# RUN apt install -y x11vnc
# RUN apt install -y vim
#/TMP
RUN apt install -y libx11-dev libxext-dev libsm-dev libxinerama-dev libxrandr-dev gettext
# RUN apt install -y lua5.2 liblua5.2-dev 
RUN apt install -y lua5.3 liblua5.3-dev 

RUN mkdir /notion
WORKDIR /notion
COPY . /notion/
RUN make && make install
ENTRYPOINT ["/usr/local/bin/notion"]
