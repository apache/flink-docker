#!/bin/bash

# This script generates a manifest compatibile with the expectations set forth
# by docker-library/official-images.
#
# It is not compatible with the version of Bash currently shipped with OS X due
# to the use of features introduced in Bash 4.

set -eu

declare -A aliases=(
    [1.11]='latest'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

# Identify directories matching '?.?' (e.g. '1.7') and remove trailing slashes
versions=( ?.?/ ?.??/ )
versions=( "${versions[@]%/}" )

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

getArches() {
    local repo="$1"; shift
    local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

    eval "declare -g -A parentRepoToArches=( $(
        find -name 'Dockerfile' -exec awk '
                toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|microsoft\/[^:]+)(:|$)/ {
                    print "'"$officialImagesUrl"'" $2
                }
            ' '{}' + \
            | sort -u \
            | xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
    ) )"
}
getArches 'flink'

cat <<-EOH
# this file is generated via https://github.com/apache/flink-docker/blob/$(fileCommit "$self")/$self

Maintainers: Patrick Lucas <me@patricklucas.com> (@patricklucas),
             Ismaël Mejía <iemejia@gmail.com> (@iemejia)
GitRepo: https://github.com/apache/flink-docker.git
EOH

# prints "$2$1$3$1...$N"
join() {
    local sep="$1"; shift
    local out; printf -v out "${sep//%/%%}%s" "$@"
    echo "${out#$sep}"
}

# Sorry for the style here, but it makes the nested code easier to read
for version in "${versions[@]}"; do

# Defaults, can vary between versions
source_variants=( debian )
scala_versions=( 2.11 2.12 )

# Version-specific variants (example)
# if [ "$flink_release" = "x.y" ]; then
#     scala_versions=( 2.10 2.11 2.12 )
# fi

for source_variant in "${source_variants[@]}"; do
for scala_version in "${scala_versions[@]}"; do
    dir="$version/scala_${scala_version}-${source_variant}"

    # Not all variant combinations may exist
    [ -f "$dir/Dockerfile" ] || continue

    commit="$(dirCommit "$dir")"

    # Extract the full Flink version from the Dockerfile
    flink_version="$(git show "$commit":"$dir/Dockerfile" | awk '/ENV FLINK_VERSION=(.*) /{ split($2,a,"="); print a[2]}')"

    full_version=$flink_version-scala_$scala_version

    variantParent="$(awk 'toupper($1) == "FROM" { print $2 }' "$dir/Dockerfile")"
    variantArches="${parentRepoToArches[$variantParent]}"

    # Start with the full version e.g. "1.2.0-scala_2.11" and add
    # additional tags as relevant
    tags=( $full_version )

    is_latest_version=
    [ "$version" = "${versions[-1]}" ] && is_latest_version=1

    is_latest_scala=
    [ "$scala_version" = "${scala_versions[-1]}" ] && is_latest_scala=1

    add_tags=( $version )

    # Add a scala version tag to each image
    tags=(
        ${tags[@]}
        ${add_tags[@]/%/-scala_$scala_version}
    )

    # If this is the latest Flink release, add a tag with only the scala version
    if [ -n "$is_latest_version" ]; then
        tags=(
            ${tags[@]}
            "scala_$scala_version"
        )
    fi

    # For the latest supported Scala version, add tags that omit the scala version
    if [ -n "$is_latest_scala" ]; then
        tags=(
            ${tags[@]}
            $flink_version
            $version
        )
    fi

    # Add -$variant suffix for non-debian-based images
    if [ "$source_variant" != "debian" ]; then
        tags=( ${tags[@]/%/-$source_variant} )
    fi

    # Finally, designate the 'latest' tag (or '$variant', for non-debian-based images)
    if [ -n "$is_latest_scala" ]; then
        alias_tag="${aliases[$version]:-}"
        if [ -n "$alias_tag" ] && [ "$source_variant" != "debian" ]; then
            alias_tag="$source_variant"
        fi

        tags=(
            ${tags[@]}
            $alias_tag
        )
    fi

    echo

    # The tabs here are necessary for the heredoc to work right
    cat <<-EOE
		Tags: $(join ', ' "${tags[@]}")
		Architectures: $(join ', ' $variantArches)
		GitCommit: $commit
		Directory: $dir
	EOE

done
done
done
