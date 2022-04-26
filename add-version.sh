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
scala_versions=( 2.12 )
java_versions=( 8 11 )
gpg_key=

# Version-specific variants (example)
# if [ "$flink_release" = "x.y" ]; then
#     scala_versions=( 2.10 2.11 2.12 )
# fi

# No real need to cull old versions
if [ "$flink_version" = "1.8.0" ]; then
    gpg_key="F2A67A8047499BBB3908D17AA8F4FD97121D7293"
elif [ "$flink_version" = "1.8.1" ]; then
    gpg_key="8FEA1EE9D0048C0CCC70B7573211B0703B79EA0E"
elif [ "$flink_version" = "1.8.2" ]; then
    gpg_key="E2C45417BED5C104154F341085BACB5AEFAE3202"
elif [ "$flink_version" = "1.8.3" ]; then
    gpg_key="EF88474C564C7A608A822EEC3FF96A2057B6476C"
elif [ "$flink_version" = "1.9.0" ]; then
    gpg_key="1C1E2394D3194E1944613488F320986D35C33D6A"
elif [ "$flink_version" = "1.9.1" ]; then
    gpg_key="E2C45417BED5C104154F341085BACB5AEFAE3202"
elif [ "$flink_version" = "1.9.2" ]; then
    gpg_key="EF88474C564C7A608A822EEC3FF96A2057B6476C"
elif [ "$flink_version" = "1.9.3" ]; then
    gpg_key="6B6291A8502BA8F0913AE04DDEB95B05BF075300"
elif [ "$flink_version" = "1.10.0" ]; then
    gpg_key="BB137807CEFBE7DD2616556710B12A1F89C115E8"
elif [ "$flink_version" = "1.11.0" ]; then
    gpg_key="2DA85B93244FDFA19A6244500653C0A2CEA00D0E"
elif [ "$flink_version" = "1.12.0" ]; then
    gpg_key="D9839159"
elif [ "$flink_version" = "1.13.0" ]; then
    gpg_key="31D2DD10BFC15A2D"
elif [ "$flink_version" = "1.14.0" ]; then
    gpg_key="31D2DD10BFC15A2D"
elif [ "$flink_version" = "1.15.0" ]; then
    gpg_key="CBE82BEFD827B08AFA843977EDBF922A7BC84897"
else
    error "Missing GPG key ID for this release"
fi

if [ -d "$flink_release" ]; then
    error "Directory $flink_release already exists; delete before continuing"
fi

mkdir "$flink_release"

source "$(dirname "$0")"/generator.sh

echo -n >&2 "Generating Dockerfiles..."
for source_variant in "${SOURCE_VARIANTS[@]}"; do
    for scala_version in "${scala_versions[@]}"; do
        for java_version in "${java_versions[@]}"; do
            dir="$flink_release/scala_${scala_version}-java${java_version}-${source_variant}"

            flink_url_file_path=flink/flink-${flink_version}/flink-${flink_version}-bin-scala_${scala_version}.tgz

            flink_tgz_url="https://www.apache.org/dyn/closer.cgi?action=download&filename=${flink_url_file_path}"
            # Not all mirrors have the .asc files
            flink_asc_url=https://www.apache.org/dist/${flink_url_file_path}.asc

            mkdir "$dir"
            generateDockerfile "${dir}" "${flink_tgz_url}" "${flink_asc_url}" ${gpg_key} true ${java_version} ${source_variant}
            generateReleaseMetadata "${dir}" ${flink_release} ${flink_version} ${scala_version} ${java_version} ${source_variant}
        done
    done
done
echo >&2 " done."
