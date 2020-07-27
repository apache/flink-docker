#!/bin/bash -e

# Defaults, can vary between versions
export SOURCE_VARIANTS=(java11-debian debian )

function generate() {
    dir=$1
    binary_download_url=$2
    asc_download_url=$3
    gpg_key=$4
    check_gpg=$5
    source_variant=$6

    from_docker_image="openjdk:8-jre"
    if [[ $source_variant =~ "java11" ]] ; then
        from_docker_image="openjdk:11-jre"
    fi

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
}
