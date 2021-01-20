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

function internal_run() {
    local dockerfile="$1"
    local docker_run_command="$2"
    local args="$3"

    local image_tag image_name
    image_tag="$(image_tag "$dockerfile")"
    image_name="$(image_name "$image_tag")"

    echo >&2 "===> Starting ${image_tag} ${args}..."

    eval "docker run --rm --detach --network $NETWORK_NAME -e JOB_MANAGER_RPC_ADDRESS=jobmanager ${docker_run_command} $image_name ${args}"
}

function internal_run_jobmanager() {
    internal_run "$1" "--name jobmanager --publish 6123:6123 --publish 8081:8081 $2" "$3"
}

function internal_run_taskmanager() {
    internal_run "$1" "--name taskmanager $2" "taskmanager"
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

function build_test_job() {
    mvn package -f testing/docker-test-job/pom.xml
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

    if [ -n "$images" ]; then
        echo >&2 -n "==> Deleting $(echo -n "$images" | grep -c '^') image(s)..."
        echo "$images" | xargs docker rmi > /dev/null
        echo >&2 " done."
    fi
}

function internal_smoke_test() {
    local dockerfile=$1
    local jm_docker_run_command_args=$2
    local jm_command_args=$3
    local tm_docker_run_command_args=$4

    jobmanager_container_id="$(internal_run_jobmanager \
        "$dockerfile" \
        "${jm_docker_run_command_args}" \
        "${jm_command_args}")"
    taskmanager_container_id="$(internal_run_taskmanager \
        "$dockerfile" \
        "${tm_docker_run_command_args}")"
    wait_for_jobmanager "$dockerfile"
    test_image "$dockerfile"
    docker kill "$jobmanager_container_id" "$taskmanager_container_id" > /dev/null
}

function internal_smoke_test_images() {
    local dockerfiles="$1"
    local docker_run_command_args="$2"

    create_network
    trap cleanup EXIT RETURN
    build_test_job

    local jobmanager_container_id
    local taskmanager_container_id

    for dockerfile in $dockerfiles; do
        build_image "$dockerfile"

        internal_smoke_test \
            "$dockerfile" \
            "${docker_run_command_args}" \
            "jobmanager" \
            "${docker_run_command_args}"
        internal_smoke_test \
            "$dockerfile" \
            "${docker_run_command_args} --mount type=bind,src=$(pwd)/testing/docker-test-job/target,target=/opt/flink/usrlib" \
            "standalone-job --job-classname org.apache.flink.StreamingJob" \
            "${docker_run_command_args} --mount type=bind,src=$(pwd)/testing/docker-test-job/target,target=/opt/flink/usrlib"
    done
}

# For each image, run a jobmanager and taskmanager and verify they start up and connect to each
# other successfully.
function smoke_test_all_images() {
    echo >&2 "==> Test all images"
    internal_smoke_test_images "$(ls ./*/*/Dockerfile)" ""
}

# Same as smoke_test_all_images, but test only the last image alphabetically (presumed to be the
# most recent).
function smoke_test_one_image() {
    echo >&2 "==> Test one image"
    internal_smoke_test_images "$(ls ./*/*/Dockerfile | tail -n 1)" ""
}

# Similar to smoke_test_one_image, but test one debian image and one alpine image running as a
# non-root user.
function smoke_test_one_image_non_root() {
    echo >&2 "==> Test images running as non-root"
    local dockerfiles="$dockerfiles $(ls ./*/*-debian/Dockerfile | tail -n 1)"
    dockerfiles="$dockerfiles $(ls ./*/*-alpine/Dockerfile | tail -n 1)"
    internal_smoke_test_images "$dockerfiles" "--user flink"
}

function test_docker_entrypoint() {
    export FLINK_HOME=$(pwd)/testing

    originalLdPreloadSetting=$LD_PRELOAD

    ./docker-entrypoint.sh $(pwd)/testing/bin/docker-entrypoint.sh hello world "$originalLdPreloadSetting" false
    DISABLE_JEMALLOC=true ./docker-entrypoint.sh $(pwd)/testing/bin/docker-entrypoint.sh hello world "$originalLdPreloadSetting" true
}

# vim: ts=4 sw=4 et
