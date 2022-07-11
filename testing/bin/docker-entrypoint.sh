#!/bin/bash -e

###############################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

if ! [ "$1" == "hello" ] || ! [ "$2" == "world" ]; then
    echo "Incorrect arguments passed through:" "$@"
    exit 1
fi

originalLdPreloadSetting=$3
jemallocDisabled=$4

if [ "$jemallocDisabled" == "true" ] && ! [ "$originalLdPreloadSetting" == "$LD_PRELOAD" ]; then
    echo "jemalloc was disabled; expected LD_PRELOAD to be '$originalLdPreloadSetting' but was '$LD_PRELOAD'"
    exit 1
fi

# We expect jemalloc to be available in any of these paths
JEMALLOC_PATH="/usr/lib/$(uname -m)-linux-gnu/libjemalloc.so"
JEMALLOC_FALLBACK="/usr/lib/x86_64-linux-gnu/libjemalloc.so"

if [ "$jemallocDisabled" == "false" ] && [ "$originalLdPreloadSetting" == "$LD_PRELOAD" ]; then
    if [ ! -f "$JEMALLOC_PATH" ] && [ ! -f "$JEMALLOC_FALLBACK" ]; then
      echo "jemalloc was enabled but it was not found in the system. LD_PRELOAD is unchanged and glibc will be used instead."
      exit 0
    fi
    echo "jemalloc was enabled; expected LD_PRELOAD to be different than '$originalLdPreloadSetting'."
    exit 1
fi
