#!/bin/bash -e

# Use this script to rebuild the Dockerfiles and all variants for a particular
# release. Before running this, you must first delete the existing release
# directory.
#
# TODO: to conform with other similar setups, this likely needs to become
# "update.sh" and be taught how to derive the latest version (e.g. 1.2.0) from
# a given release (e.g. 1.2) and assemble a .travis.yml file dynamically.
#
# See other repos (e.g. httpd, cassandra) for update.sh examples.

function usage() {
    echo >&2 "usage: $0 -r flink-release -f flink-version"
}

function error() {
    local msg="$1"
    if [ -n "$2" ]; then
        local code="$2"
    else
        local code=1
    fi
    echo >&2 "$msg"
    exit "$code"
}

flink_release= # Like 1.2
flink_version= # Like 1.2.0

while getopts r:f:h arg; do
  case "$arg" in
    r)
      flink_release=$OPTARG
      ;;
    f)
      flink_version=$OPTARG
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

if [ -z "$flink_release" ] || [ -z "$flink_version" ]; then
    usage
    exit 1
fi

if [[ ! "$flink_version" =~ ^$flink_release\.+ ]]; then
    error "Flink release must be prefix of version"
fi

# Defaults, can vary between versions
source_variants=( debian alpine )
hadoop_variants=( 24 26 27 28 0 )
scala_variants=( 2.11 )
docker_entrypoint="docker-entrypoint.sh"

# Version-specific variants (example)
# if [ "$flink_release" = "x.y" ]; then
#     scala_variants=( 2.10 2.11 2.12 )
# fi

if [ -d "$flink_release" ]; then
    error "Directory $flink_release already exists; delete before continuing"
fi

echo -n >&2 "Checking for latest KEYS..."
wget -q -O "KEYS" https://www.apache.org/dist/flink/KEYS
echo >&2 " done."

mkdir "$flink_release"

echo -n >&2 "Generating Dockerfiles..."
for source_variant in "${source_variants[@]}"; do
    for hadoop_variant in "${hadoop_variants[@]}"; do
        for scala_variant in "${scala_variants[@]}"; do
            if [ "$hadoop_variant" = "0" ]; then
                hadoop_scala_variant="scala_${scala_variant}"
            else
                hadoop_scala_variant="hadoop${hadoop_variant}-scala_${scala_variant}"
            fi

            dir="$flink_release/${hadoop_scala_variant}-${source_variant}"

            mkdir "$dir"
            cp KEYS "$dir/KEYS"
            cp "$docker_entrypoint" "$dir/docker-entrypoint.sh"

            sed \
                -e "s/%%FLINK_VERSION%%/$flink_version/" \
                -e "s/%%HADOOP_SCALA_VARIANT%%/$hadoop_scala_variant/" \
                "Dockerfile-$source_variant.template" > "$dir/Dockerfile"
        done
    done
done
echo >&2 " done."
