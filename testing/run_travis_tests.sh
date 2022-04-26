#!/bin/bash -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "${SCRIPT_DIR}/testing_lib.sh"

IS_PULL_REQUEST=
if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
  IS_PULL_REQUEST=1
fi

BRANCH="$TRAVIS_BRANCH"

test_docker_entrypoint

./add-custom.sh -u "https://s3.amazonaws.com/flink-nightly/flink-1.16-SNAPSHOT-bin-scala_2.12.tgz" -j 8 -n test-java8

# test Flink with Java11 image as well
./add-custom.sh -u "https://s3.amazonaws.com/flink-nightly/flink-1.16-SNAPSHOT-bin-scala_2.12.tgz" -j 11 -n test-java11

smoke_test_all_images
smoke_test_one_image_non_root


echo "Test successfully finished"

# vim: et ts=2 sw=2
