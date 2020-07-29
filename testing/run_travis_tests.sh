#!/bin/bash -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "${SCRIPT_DIR}/testing_lib.sh"

IS_PULL_REQUEST=
if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
  IS_PULL_REQUEST=1
fi

BRANCH="$TRAVIS_BRANCH"

function run_tests {
	if [ -z "$IS_PULL_REQUEST" ] && [ "$BRANCH" = "dev-master" ]; then
  smoke_test_all_images
  smoke_test_one_image_non_root
else
  # For pull requests and branches, test one image
  smoke_test_one_image
fi
}

./add-custom.sh -u "https://s3.amazonaws.com/flink-nightly/flink-1.11-SNAPSHOT-bin-hadoop2.tgz"
run_tests

rm -r dev

# test Flink with Java11 image as well
./add-custom.sh -u "https://s3.amazonaws.com/flink-nightly/flink-1.11-SNAPSHOT-bin-hadoop2.tgz" -j 11
run_tests

echo "Test successfully finished"

# vim: et ts=2 sw=2
