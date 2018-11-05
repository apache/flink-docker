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
    local dockerfile="$1"

    local variant="$(basename "$(dirname "$dockerfile")")"
    local minor_version="$(dirname "$(dirname "$dockerfile")")"

    echo "${minor_version}-${variant}"
}

function image_name() {
    local image_tag="$1"

    echo "${IMAGE_REPO}:${image_tag}"
}

function build_image() {
    local dockerfile="$1"

    local image_tag="$(image_tag "$dockerfile")"
    local image_name="$(image_name "$image_tag")"
    local dockerfile_dir="$(dirname "$dockerfile")"

    echo >&2 "Building ${image_tag} image..."
    docker build -t "$image_name" "$dockerfile_dir"
}

function run_jobmanager() {
    local dockerfile="$1"

    local image_tag="$(image_tag "$dockerfile")"
    local image_name="$(image_name "$image_tag")"

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

function wait_for_jobmanager() {
    local dockerfile="$1"

    local image_tag="$(image_tag "$dockerfile")"

    i=0
    echo >&2 "Waiting for ${image_tag} jobmanager to be ready..."
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
            echo >&2 "\$CURL_MAX_TRIES exceeded waiting for jobmanager to be ready"
            return 1
        fi

        sleep "$CURL_COOLDOWN"
    done

    echo >&2 "${image_tag} jobmanager is ready."
}

function run_taskmanager() {
    local dockerfile="$1"

    local image_tag="$(image_tag "$dockerfile")"
    local image_name="$(image_name "$image_tag")"

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

function test_image() {
    local dockerfile="$1"

    local image_tag="$(image_tag "$dockerfile")"

    i=0
    echo >&2 "Waiting for ${image_tag} taskmanager to connect..."
    while true; do
        i=$((i+1))
    
        set +e
    
        local overview="$(curl \
            --silent \
            --max-time "$CURL_TIMEOUT" \
            "$CURL_ENDPOINT")"
    
        num_taskmanagers="$(echo "$overview" | jq .taskmanagers)"

        set -e

        if [ "$num_taskmanagers" = "1" ]; then
            break
        fi
    
        if [ "$i" -gt "$CURL_MAX_TRIES" ]; then
            echo >&2 "\$CURL_MAX_TRIES exceeded for taskmanager to connect"
            return 1
        fi
    
        sleep "$CURL_COOLDOWN"
    done

    echo >&2 "${image_tag} taskmanager connected."
}

function create_network() {
    docker network create "$NETWORK_NAME" > /dev/null
}

# Find and kill any remaining containers attached to the network, then remove
# the network.
function cleanup() {
    local containers="$(docker ps --quiet --filter network="$NETWORK_NAME")"

    if [ -n "$containers" ]; then
        local num_containers="$(echo "$containers" | awk 'END{print NR}')"
        echo >&2 -n "Killing ${num_containers} orphaned container(s)..."
        docker kill $containers > /dev/null
        echo >&2 " done."
    fi

    docker network rm "$NETWORK_NAME" > /dev/null
}

function build_images() {
    create_network
    trap cleanup EXIT

    local jobmanager_container_id
    local taskmanager_container_id

    for dockerfile in */*/Dockerfile; do
        build_image "$dockerfile"
        jobmanager_container_id="$(run_jobmanager "$dockerfile")"
        wait_for_jobmanager "$dockerfile"
        taskmanager_container_id="$(run_taskmanager "$dockerfile")"
        test_image "$dockerfile"
        docker kill "$jobmanager_container_id" "$taskmanager_container_id" > /dev/null
    done
}

build_images
