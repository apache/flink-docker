#!/usr/bin/env bash

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This script generates a manifest compatibile with the expectations set forth
# by docker-library/official-images.
#
# It is not compatible with the version of Bash currently shipped with OS X due
# to the use of features introduced in Bash 4.

set -eu

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

source common.sh

cat <<-EOH
# this file is generated via https://github.com/apache/flink-docker/blob/$(fileCommit "$self")/$self

Maintainers: The Apache Flink Project <dev@flink.apache.org> (@ApacheFlink)
GitRepo: https://github.com/apache/flink-docker.git
EOH


for dockerfile in $(find . -name "Dockerfile" | sort -r); do
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
