#!/bin/bash -e

# Defaults, can vary between versions
export SOURCE_VARIANTS=( debian )

function generate() {
    dir=$1
    binary_download_url=$2
    asc_download_url=$3
    gpg_key=$4
    check_gpg=$5
    source_variant=$6

    mkdir "$dir"
    cp docker-entrypoint.sh "$dir/docker-entrypoint.sh"

    # '&' has special semantics in sed replacement patterns
    escaped_binary_download_url=$(echo "$binary_download_url" | sed 's/&/\\\&/')

    sed \
        -e "s,%%BINARY_DOWNLOAD_URL%%,${escaped_binary_download_url}," \
        -e "s,%%ASC_DOWNLOAD_URL%%,$asc_download_url," \
        -e "s/%%GPG_KEY%%/$gpg_key/" \
        -e "s/%%CHECK_GPG%%/${check_gpg}/" \
        "Dockerfile-$source_variant.template" > "$dir/Dockerfile"
}
