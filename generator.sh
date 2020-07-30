#!/bin/bash -e

export SOURCE_VARIANTS=(debian )

export DEFAULT_SCALA="2.12"

function generateDockerfile {
    # define variables
    dir=$1
    binary_download_url=$2
    asc_download_url=$3
    gpg_key=$4
    check_gpg=$5
    source_variant=$6

    from_docker_image="openjdk:8-jre"

    cp docker-entrypoint.sh "$dir/docker-entrypoint.sh"

    # '&' has special semantics in sed replacement patterns
    escaped_binary_download_url=$(echo "$binary_download_url" | sed 's/&/\\\&/')

    # generate Dockerfile
    sed \
        -e "s,%%BINARY_DOWNLOAD_URL%%,${escaped_binary_download_url}," \
        -e "s,%%ASC_DOWNLOAD_URL%%,$asc_download_url," \
        -e "s/%%GPG_KEY%%/$gpg_key/" \
        -e "s/%%CHECK_GPG%%/${check_gpg}/" \
        -e "s/%%FROM_IMAGE%%/${from_docker_image}/" \
        "Dockerfile-$source_variant.template" > "$dir/Dockerfile"
}

function generateReleaseMetadata {
    dir=$1
    flink_release=$2
    flink_version=$3
    scala_version=$4

    # example "1.2.0-scala_2.11"
    full_tag=${flink_version}-scala_${scala_version}

    # example "1.2-scala_2.11"
    short_tag=${flink_release}-scala_${scala_version}

    # example "scala_2.12-"
    scala_tag="scala_${scala_version}"

    tags="$full_tag, $short_tag, $scala_tag"

    if [[ "$scala_version" == "$DEFAULT_SCALA" ]]; then
        # we are generating the image for the latest scala version, add:
        # "1.2.0"
        # "1.2"
        # "latest"
        tags="$tags, ${flink_version}, ${flink_release}, latest"
    fi

    echo "Tags: $tags" >> $dir/release.metadata

    # We currently only support amd64 with Flink.
    echo "Architectures: amd64" >> $dir/release.metadata
}
