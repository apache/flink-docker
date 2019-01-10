#!/bin/bash -e

SCRIPT_DIR=$( cd $( dirname "$0" ) && pwd )

. "${SCRIPT_DIR}/testing_lib.sh"

IS_PULL_REQUEST=
if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
  IS_PULL_REQUEST=1
fi

BRANCH="$TRAVIS_BRANCH"

if [ -z "$IS_PULL_REQUEST" ] && [ "$BRANCH" = "master" ]; then
  # Test all images on master
  smoke_test_all_images
  smoke_test_non_root
else
  # For pull requests and branches, test one image
  smoke_test_one_image
fi
