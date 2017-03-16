#!/bin/bash
set -eu

declare -A aliases=(
    [1.2]='latest'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )

source_variants=( debian alpine )
hadoop_variants=( 1 2 24 26 27 )
scala_variants=( 2.10 2.11 )

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

cat <<-EOH
# this file is generated via https://github.com/docker-flink/docker-flink/blob/$(fileCommit "$self")/$self

Maintainers: Patrick Lucas <me@patricklucas.com> (@patricklucas),
             Ismaël Mejía <iemejia@gmail.com> (@iemejia)
GitRepo: https://github.com/docker-flink/docker-flink.git
EOH

# prints "$2$1$3$1...$N"
join() {
    local sep="$1"; shift
    local out; printf -v out "${sep//%/%%}%s" "$@"
    echo "${out#$sep}"
}

# Sorry for the style here, but it makes the nested code easier to read
for version in "${versions[@]}"; do
for source_variant in "${source_variants[@]}"; do
for hadoop_variant in "${hadoop_variants[@]}"; do
for scala_variant in "${scala_variants[@]}"; do

    dir="$version/hadoop$hadoop_variant-scala_$scala_variant-$source_variant"

    # Not all Hadoop/Scala combinations may exist
    [ -f "$dir/Dockerfile" ] || continue

    commit="$(dirCommit "$dir")"

    # Extract the full Flink version from the Dockerfile
    flink_version="$(git show "$commit":"$dir/Dockerfile" | awk '/ENV FLINK_VERSION=(.*) /{ split($2,a,"="); print a[2]}')"

    full_version=$flink_version-hadoop$hadoop_variant-scala_$scala_variant

    # Start with the full version e.g. "1.2.0-hadoop27-scala_2.11" and add
    # additional tags as relevant
    tags=( $full_version )

    # For the latest supported Hadoop version, add tags that omit it
    if [ "$hadoop_variant" = "${hadoop_variants[-1]}" ]; then
        add_tags=( $flink_version $version ${aliases[$version]:-} )
        tags=(
            ${tags[@]}
            ${add_tags[@]/%/-scala_$scala_variant}
        )
    fi

    # For the latest supported Scala version, add tags that omit it
    if [ "$scala_variant" = "${scala_variants[-1]}" ]; then
        # The last element of add_tags must not have surrounding quotes!
        add_tags=( $flink_version $version ${aliases[$version]:-} )
        tags=(
            ${tags[@]}
            ${add_tags[@]/%/-hadoop$hadoop_variant}
        )
    fi

    # For the latest supported Hadoop & Scala version, add tags that omit them
    if [ "$hadoop_variant" = "${hadoop_variants[-1]}" ] && [ "$scala_variant" = "${scala_variants[-1]}" ]; then
        tags=(
            ${tags[@]}
            $flink_version
            $version
            ${aliases[$version]:-}
        )
    fi

    # Add -$variant suffix for non-debian-based images
    if [ "$source_variant" != "debian" ]; then
        tags=( ${tags[@]/%/-$source_variant} )
    fi

    echo

    # The tabs here are necessary for the heredoc to work right
    cat <<-EOE
		Tags: $(join ', ' "${tags[@]}")
		GitCommit: $commit
		Directory: $dir
	EOE

done
done
done
done
