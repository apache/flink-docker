#!/bin/bash -e

# Defaults, can vary between versions
export SOURCE_VARIANTS=(java11-debian debian )

export LATEST_SCALA="2.12"

function generate() {
    # define variables
    dir=$1
    binary_download_url=$2
    asc_download_url=$3
    gpg_key=$4
    check_gpg=$5
    flink_release=$6
    flink_version=$7
    scala_version=$8
    source_variant=$9

    from_docker_image="openjdk:8-jre"
    if [[ $source_variant =~ "java11" ]] ; then
        from_docker_image="openjdk:11-jre"
    fi

    ########################################
    ### generate "Dockerfile" file
    ########################################

    # overwrite variable based on $source_variant to support non-debian releases
    source_file="Dockerfile-debian"

    mkdir "$dir"
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
        "$source_file.template" > "$dir/Dockerfile"

    ########################################
    ### generate "release.metadata" file
    ########################################
    
    # docker image tags:
    java11_suffix=""
    if [[ $source_variant =~ "java11" ]] ; then
        java11_suffix="-java11"
    fi
    # example "1.2.0-scala_2.11-java11"
    full_tag=${flink_version}-scala_${scala_version}${java11_suffix}

    # example "1.2-scala_2.11-java11"
    short_tag=${flink_release}-scala_${scala_version}${java11_suffix}

    # example "scala_2.12-java11"
    scala_tag="scala_${scala_version}${java11_suffix}"

    tags="$full_tag, $short_tag, $scala_tag"

    if [[ "$scala_version" == "$LATEST_SCALA" ]]; then
        # we are generating the image for the latest scala version, add:
        # "1.2.0-java11"
        # "1.2-java11"
        # "latest-java11"
        tags="$tags, ${flink_version}${java11_suffix}, ${flink_release}${java11_suffix}, latest${java11_suffix}"
    fi

    echo "Tags: $tags" >> $dir/release.metadata

    # We currently only support amd64 with Flink.
    echo "Architectures: amd64" >> $dir/release.metadata

}
