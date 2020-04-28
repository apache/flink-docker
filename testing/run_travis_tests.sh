#!/bin/bash -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "${SCRIPT_DIR}/testing_lib.sh"

IS_PULL_REQUEST=
if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
  IS_PULL_REQUEST=1
fi

BRANCH="$TRAVIS_BRANCH"

if [ -n "$IS_PULL_REQUEST" ]; then
  changed_files="$(git diff --name-only $BRANCH...HEAD)"

  echo "Changed files in this pull request:"
  echo "${changed_files}"
  echo
fi

./add-version.sh -r 1.10 -f 1.10.0

if [ -z "$IS_PULL_REQUEST" ] && [ "$BRANCH" = "dev-1.10" ]; then
  smoke_test_all_images
  smoke_test_one_image_non_root
else
  # For pull requests and branches, test one image
  smoke_test_one_image
fi

# vim: et ts=2 sw=2
