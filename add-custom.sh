#!/bin/bash -eu

# Use this script to build the Dockerfiles against an arbitrary
# Flink distribution.
# This is exlusively for development purposes.

source "$(dirname "$0")"/generator.sh

function usage() {
    echo >&2 "usage: $0 -u binary-download-url [-n name] [-j java_version]"
}

binary_download_url=
name=custom
java_version=${DEFAULT_JAVA}

while getopts u:n:j:h arg; do
  case "$arg" in
    u)
      binary_download_url=$OPTARG
      ;;
    n)
      name=$OPTARG
      ;;
    j)
      java_version=$OPTARG
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done

if [ -z "${binary_download_url}" ]; then
    usage
    exit 1
fi

mkdir -p "dev"

echo -n >&2 "Generating Dockerfiles..."
for source_variant in "${SOURCE_VARIANTS[@]}"; do
  dir="dev/${name}-${source_variant}"
  rm -rf "${dir}"
  mkdir "$dir"
  generateDockerfile "${dir}" "${binary_download_url}" "" "" false ${java_version} ${source_variant}
done
echo >&2 " done."
