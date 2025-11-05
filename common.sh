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
    local tags=$1
    local latestVersion=$2
    # Escape dots in version for proper regex matching
    local escapedVersion="${latestVersion//./\\.}"
    if [[ $tags =~ (^|[, ])$escapedVersion([, -]|$) ]]; then
        # tags contains latest version. keep "latest" tag
        echo $tags
    else
        # remove "latest", any "scala_" or "javaXX" tag, unless it is the latest version
        # the "scala" / "java" tags have a similar semantic as the "latest" tag in docker registries.
        echo $tags | sed -E 's#, (scala|latest|java[0-9]{1,2})[-_.[:alnum:]]*##g'
    fi
}

extractValue() {
    local key="$1"
    local file="$2"
    local line=$(cat $file | grep "$key:")
    echo $line | sed "s/${key}: //g"
}

# get latest flink version
latest_version=`ls -1a | grep -E "[0-9]+.[0-9]+" | sort -V -r | head -n 1`
