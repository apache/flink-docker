#!/bin/bash -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "${SCRIPT_DIR}/testing_lib.sh"

IS_PULL_REQUEST=
if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
  IS_PULL_REQUEST=1
fi

BRANCH="$TRAVIS_BRANCH"

./add-version.sh -r 1.13 -f 1.13.2

test_docker_entrypoint

smoke_test_all_images
smoke_test_one_image_non_root


echo "Test successfully finished"

# vim: et ts=2 sw=2
