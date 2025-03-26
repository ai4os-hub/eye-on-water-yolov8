# Dockerfile may have following Arguments:
# tag - tag for the Base image, (e.g. 2.9.1 for tensorflow)
# branch - user repository branch to clone (default: master, another option: test)
#
# To build the image:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> --build-arg arg=value .
# or using default args:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> .
#
# Be Aware! For the Jenkins CI/CD pipeline, 
# input args are defined inside the JenkinsConstants.groovy, not here!

ARG tag=2.18.0
# Base image, e.g. tensorflow/tensorflow:2.9.1
FROM tensorflow/tensorflow:${tag}

LABEL maintainer='Thomas Warbout'
LABEL version='0.0.1'
# eye on water yolov8  is an application using the DEEPaaS API.

# What user branch to clone [!]
ARG branch=main

# Install Ubuntu packages
# - gcc is needed in Pytorch images because deepaas installation might break otherwise (see docs) (it is already installed in tensorflow images)
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        git \
        curl \
        nano \
        psmisc \
        libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Update python packages
# [!] Remember: DEEP API V2 only works with python>=3.6
RUN python3 --version && \
    pip3 install --no-cache-dir --upgrade pip "setuptools<60.0.0" wheel

# TODO: remove setuptools version requirement when [1] is fixed
# [1]: https://github.com/pypa/setuptools/issues/3301

# Set LANG environment
ENV LANG=C.UTF-8

# Set the working directory
WORKDIR /srv

# Install rclone (needed if syncing with NextCloud for training; otherwise remove)
RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.deb && \
    dpkg -i rclone-current-linux-amd64.deb && \
    apt install -f && \
    mkdir /srv/.rclone/ && \
    touch /srv/.rclone/rclone.conf && \
    rm rclone-current-linux-amd64.deb && \
    rm -rf /var/lib/apt/lists/*

ENV RCLONE_CONFIG=/srv/.rclone/rclone.conf

# Disable FLAAT authentication by default
ENV DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER=yes

# Initialization scripts
# deep-start can install JupyterLab or VSCode if requested
RUN git clone https://github.com/ai4os/deep-start /srv/.deep-start && \
    ln -s /srv/.deep-start/deep-start.sh /usr/local/bin/deep-start

# Necessary for the Jupyter Lab terminal
ENV SHELL=/bin/bash

# Install user app
RUN git clone -b $branch https://github.com/ai4os-hub/eye-on-water-yolov8 && \
    cd  eye-on-water-yolov8 && \
    pip3 install --no-cache-dir -e . && \
    cd ..

COPY requirements.txt /srv/requirements.txt
RUN pip3 install --no-cache-dir -r /srv/requirements.txt

# COPY . eyeonwater_yolov8
# RUN cd eyeonwater_yolov8 && \
#     pip3 install --no-cache-dir -e . && \
#     cd ..

# # Copy the YOLO model directory
# COPY eyeonwater_yolov8/models /srv/eyeonwater_yolov8/models

# Open ports: DEEPaaS (5000), Monitoring (6006), Jupyter (8888)
EXPOSE 5000 6006 8888

# Launch deepaas
# CMD [ "deep-start", "--deepaas" ]
CMD ["deepaas-run", "--listen-ip", "0.0.0.0", "--listen-port", "5000"]

