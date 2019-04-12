#!/bin/bash -e

# This test script discovers all image variants, builds them, then runs a
# simple smoke test for each:
# - start up a jobmanager
# - wait for the /overview web UI endpoint to return successfully
# - start up a taskmanager
# - wait for the /overview web UI endpoint to report 1 connected taskmanager

CURL_TIMEOUT=1
CURL_COOLDOWN=1
CURL_MAX_TRIES=30
CURL_ENDPOINT=localhost:8081/overview
IMAGE_REPO=docker-flink-test
NETWORK_NAME=docker-flink-test-net

function image_tag() {
    local dockerfile
    dockerfile="$1"

    local variant minor_version
    variant="$(basename "$(dirname "$dockerfile")")"
    minor_version="$(basename "$(dirname "$(dirname "$dockerfile")")")"

    echo "${minor_version}-${variant}"
}

function image_name() {
    local image_tag
    image_tag="$1"

    echo "${IMAGE_REPO}:${image_tag}"
}

function build_image() {
    local dockerfile
    dockerfile="$1"

    local image_tag image_name dockerfile_dir
    image_tag="$(image_tag "$dockerfile")"
    image_name="$(image_name "$image_tag")"
    dockerfile_dir="$(dirname "$dockerfile")"

    echo >&2 "===> Building ${image_tag} image..."
    docker build -t "$image_name" "$dockerfile_dir"
}

function run_jobmanager() {
    local dockerfile
    dockerfile="$1"

    local image_tag image_name
    image_tag="$(image_tag "$dockerfile")"
    image_name="$(image_name "$image_tag")"

    echo >&2 "===> Starting ${image_tag} jobmanager..."

    # Prints container ID
    docker run \
        --rm \
        --detach \
        --name "jobmanager" \
        --network "$NETWORK_NAME" \
        --publish 6123:6123 \
        --publish 8081:8081 \
        -e JOB_MANAGER_RPC_ADDRESS="jobmanager" \
        "$image_name" \
        jobmanager
}

function run_jobmanager_non_root() {
    local dockerfile
    dockerfile="$1"

    local image_tag image_name
    image_tag="$(image_tag "$dockerfile")"
    image_name="$(image_name "$image_tag")"

    echo >&2 "===> Starting ${image_tag} jobmanager as non-root..."

    # Prints container ID
    docker run \
        --rm \
        --detach \
        --name "jobmanager" \
        --network "$NETWORK_NAME" \
        --user 1234 \
        --publish 6123:6123 \
        --publish 8081:8081 \
        -e JOB_MANAGER_RPC_ADDRESS="jobmanager" \
        "$image_name" \
        jobmanager
}

function wait_for_jobmanager() {
    local dockerfile
    dockerfile="$1"

    local image_tag
    image_tag="$(image_tag "$dockerfile")"

    i=0
    echo >&2 "===> Waiting for ${image_tag} jobmanager to be ready..."
    while true; do
        i=$((i+1))
    
        set +e
    
        curl \
            --silent \
            --max-time "$CURL_TIMEOUT" \
            "$CURL_ENDPOINT" \
            > /dev/null
    
        result=$?

        set -e

        if [ "$result" -eq 0 ]; then
            break
        fi
    
        if [ "$i" -gt "$CURL_MAX_TRIES" ]; then
            echo >&2 "===> \$CURL_MAX_TRIES exceeded waiting for jobmanager to be ready"
            return 1
        fi

        sleep "$CURL_COOLDOWN"
    done

    echo >&2 "===> ${image_tag} jobmanager is ready."
}

function run_taskmanager() {
    local dockerfile
    dockerfile="$1"

    local image_tag image_name
    image_tag="$(image_tag "$dockerfile")"
    image_name="$(image_name "$image_tag")"

    echo >&2 "===> Starting ${image_tag} taskmanager..."

    # Prints container ID
    docker run \
        --rm \
        --detach \
        --name "taskmanager" \
        --network "$NETWORK_NAME" \
        -e JOB_MANAGER_RPC_ADDRESS="jobmanager" \
        "$image_name" \
        taskmanager
}

function run_taskmanager_non_root() {
    local dockerfile
    dockerfile="$1"

    local image_tag image_name
    image_tag="$(image_tag "$dockerfile")"
    image_name="$(image_name "$image_tag")"

    echo >&2 "===> Starting ${image_tag} taskmanager as non-root..."

    # Prints container ID
    docker run \
        --rm \
        --detach \
        --name "taskmanager" \
        --network "$NETWORK_NAME" \
        --user 1234 \
        -e JOB_MANAGER_RPC_ADDRESS="jobmanager" \
        "$image_name" \
        taskmanager
}

function test_image() {
    local dockerfile
    dockerfile="$1"

    local image_tag
    image_tag="$(image_tag "$dockerfile")"

    i=0
    echo >&2 "===> Waiting for ${image_tag} taskmanager to connect..."
    while true; do
        i=$((i+1))
    
        set +e
    
        local overview
        overview="$(curl \
            --silent \
            --max-time "$CURL_TIMEOUT" \
            "$CURL_ENDPOINT")"
    
        num_taskmanagers="$(echo "$overview" | jq .taskmanagers)"

        set -e

        if [ "$num_taskmanagers" = "1" ]; then
            break
        fi
    
        if [ "$i" -gt "$CURL_MAX_TRIES" ]; then
            echo >&2 "===> \$CURL_MAX_TRIES exceeded for taskmanager to connect"
            return 1
        fi
    
        sleep "$CURL_COOLDOWN"
    done 
    echo >&2 "===> ${image_tag} taskmanager connected."
}

function create_network() {
    docker network create "$NETWORK_NAME" > /dev/null
}

# Find and kill any remaining containers attached to the network, then remove
# the network and any images produced by the build.
function cleanup() {
    local containers
    containers="$(docker ps --quiet --filter network="$NETWORK_NAME")"

    if [ -n "$containers" ]; then
        echo >&2 -n "==> Killing $(echo -n "$containers" | grep -c '^') orphaned container(s)..."
        echo "$containers" | xargs docker kill > /dev/null
        echo >&2 " done."
    fi

    docker network rm "$NETWORK_NAME" > /dev/null 2>&1 || true

    local images
    images="$(docker images --quiet --filter reference="$IMAGE_REPO")"
    echo "$images" | docker rmi > /dev/null
}

# For each image, run a jobmanager and taskmanager and verify they start up and connect to each
# other successfully.
function smoke_test_all_images() {
    create_network
    trap cleanup EXIT RETURN

    local jobmanager_container_id
    local taskmanager_container_id
    local dockerfiles
    dockerfiles="$(ls ./*/*/Dockerfile)"

    echo >&2 "==> Test all images"

    for dockerfile in $dockerfiles; do
        build_image "$dockerfile"
        jobmanager_container_id="$(run_jobmanager "$dockerfile")"
        taskmanager_container_id="$(run_taskmanager "$dockerfile")"
        wait_for_jobmanager "$dockerfile"
        test_image "$dockerfile"
        docker kill "$jobmanager_container_id" "$taskmanager_container_id" > /dev/null
    done
}

# Same as smoke_test_all_images, but test only the last image alphabetically (presumed to be the
# most recent).
function smoke_test_one_image() {
    create_network
    trap cleanup EXIT RETURN

    local jobmanager_container_id
    local taskmanager_container_id
    local dockerfiles
    dockerfiles="$dockerfiles $(ls ./*/*/Dockerfile | tail -n 1)"

    echo >&2 "==> Test one image"

    for dockerfile in $dockerfiles; do
        build_image "$dockerfile"
        jobmanager_container_id="$(run_jobmanager "$dockerfile")"
        taskmanager_container_id="$(run_taskmanager "$dockerfile")"
        wait_for_jobmanager "$dockerfile"
        test_image "$dockerfile"
        docker kill "$jobmanager_container_id" "$taskmanager_container_id" > /dev/null
    done
}

# Similar to smoke_test_one_image, but test one debian image and one alpine image running as a
# non-root user.
function smoke_test_non_root() {
    create_network
    trap cleanup EXIT RETURN

    local jobmanager_container_id
    local taskmanager_container_id
    local dockerfiles
    dockerfiles="$dockerfiles $(ls ./*/*-debian/Dockerfile | tail -n 1)"
    dockerfiles="$dockerfiles $(ls ./*/*-alpine/Dockerfile | tail -n 1)"

    echo >&2 "==> Test images running as non-root"

    for dockerfile in $dockerfiles; do
        build_image "$dockerfile"
        jobmanager_container_id="$(run_jobmanager_non_root "$dockerfile")"
        taskmanager_container_id="$(run_taskmanager_non_root "$dockerfile")"
        wait_for_jobmanager "$dockerfile"
        test_image "$dockerfile"
        docker kill "$jobmanager_container_id" "$taskmanager_container_id" > /dev/null
    done
}

# vim: ts=4 sw=4 et
