#!/usr/bin/env bash

exec docker run --rm \
    --volume "${PWD}:/build:ro" \
    rmetzger/git-and-bash:latest \
    /build/generate-stackbrew-library.sh
