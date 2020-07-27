#!/usr/bin/env bash

# This script generates a manifest compatibile with the expectations set forth
# by docker-library/official-images.
#
# It is not compatible with the version of Bash currently shipped with OS X due
# to the use of features introduced in Bash 4.

set -eu

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

# remove "latest" and any "scala_" tag, unless it is the latest version
PRUNE_FROM_NON_LATEST_VERSION="^(latest$|scala\_/*)"

# get the most recent commit which modified any of "$@"
fileCommit() {
    git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
    local dir="$1"; shift
    (
        cd "$dir"
        fileCommit \
            Dockerfile \
            $(git show HEAD:./Dockerfile | awk '
                toupper($1) == "COPY" {
                    for (i = 2; i < NF; i++) {
                        print $i
                    }
                }
            ')
    )
}

# Inputs:
#  - tags: comma-seprated list of image tags
#  - latestVersion: latest version
# Output: comma-separated list of tags with "latest" removed if not latest version
pruneTags() {
    local inTagsString=$1
    local latestVersion=$2
    if [[ $inTagsString =~ $latestVersion ]]; then
        # tagsString contains latest version. keep "latest" tag
        echo $inTagsString
    else
        # split list of tags, remove anything containing "latest"
        IFS=', ' read -r -a inTags <<< "$inTagsString"
        local outString=""
        for inTag in "${inTags[@]}"; do
            if [[ $inTag =~ $PRUNE_FROM_NON_LATEST_VERSION ]]; then
                continue;
            fi
            outString="$outString, $inTag"
        done
        echo ${outString:2}
    fi
}

extractValue() {
    local key="$1"
    local file="$2"
    local line=$(cat $file | grep "$key:")
    echo $line | cut -d ':' -f 2 | xargs # remove key from line, remove whitespace
}

# get latest flink version
latest_version=`ls -1a | grep -E "[0-9]+.[0-9]+" | sort -V -r | head -n 1`

cat <<-EOH
# this file is generated via https://github.com/apache/flink-docker/blob/$(fileCommit "$self")/$self

Maintainers: Patrick Lucas <me@patricklucas.com> (@patricklucas),
             Ismaël Mejía <iemejia@gmail.com> (@iemejia)
GitRepo: https://github.com/apache/flink-docker.git
EOH


for dockerfile in $(find . -name "Dockerfile"); do
    dir=$(dirname $dockerfile)

    commit="$(dirCommit "$dir")"
    metadata="$dir/release.metadata"
    architectures=$(extractValue "Architectures" $metadata)
    tags=$(extractValue "Tags" $metadata)
    tags=$(pruneTags "$tags" $latest_version)

    # newline
    echo

    # The tabs here are necessary for the heredoc to work right
    cat <<-EOE
		Tags: $tags
		Architectures: $architectures
		GitCommit: $commit
		Directory: $dir
	EOE

done
