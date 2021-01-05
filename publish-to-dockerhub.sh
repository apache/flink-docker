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

# This script publishes the Flink docker images to any Docker registry. By default it's configured to the apache/flink DockerHub account.

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

source common.sh

TARGET_REGISTRY=${TARGET_REGISTRY:-"apache/flink"}

echo "Publishing to target registry: $TARGET_REGISTRY"

for dockerfile in $(find . -name "Dockerfile"); do
    dir=$(dirname $dockerfile)

    metadata="$dir/release.metadata"
    tags=$(extractValue "Tags" $metadata)
    tags=$(pruneTags "$tags" $latest_version)

    echo "Building image in $dir"

    DOCKER_BUILD_CMD="docker build"
    DOCKER_PUSH_CMDS=()
    IFS=',' read -ra TAGS_ARRAY <<< "$tags"
	for raw_tag in "${TAGS_ARRAY[@]}"; do
		# trim whitespace
		tag=`echo $raw_tag | xargs`
	    DOCKER_BUILD_CMD+=" -t $TARGET_REGISTRY:$tag"
	    DOCKER_PUSH_CMDS+=( "docker push $TARGET_REGISTRY:$tag")
	done
	DOCKER_BUILD_CMD+=" $dir"
	echo -e "\tBuilding docker image using command"
	echo -e "\t\t$DOCKER_BUILD_CMD"
	eval $DOCKER_BUILD_CMD
	echo -e "\tPushing tags"
	for push_cmd in "${DOCKER_PUSH_CMDS[@]}"; do
		echo -e "\t\tPushing using $push_cmd"
		eval $push_cmd
	done

	#newline
	echo
done
