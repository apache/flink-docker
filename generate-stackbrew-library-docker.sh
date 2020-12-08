#!/usr/bin/env bash

# How to recreate below docker image
# 
# $ cat Dockerfile
# FROM ubuntu:16.04
# RUN apt-get update ; apt-get install -y git bash
# 
# $ docker build -t rmetzger/git-and-bash:latest .
# $ docker push rmetzger/git-and-bash:latest
#

exec docker run --rm \
    --volume "${PWD}:/build:ro" \
    rmetzger/git-and-bash:latest \
    /build/generate-stackbrew-library.sh
