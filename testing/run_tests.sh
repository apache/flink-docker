#!/bin/bash -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "${SCRIPT_DIR}/testing_lib.sh"


test_docker_entrypoint

smoke_test_all_images
smoke_test_one_image_non_root


echo "Test successfully finished"

# vim: et ts=2 sw=2
