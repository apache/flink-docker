#!/bin/bash

exec docker run --rm \
    --volume "${PWD}:/build:ro" \
    plucas/docker-flink-build \
    /build/generate-stackbrew-library.sh
