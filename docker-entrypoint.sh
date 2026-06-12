#!/usr/bin/env bash

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

COMMAND_STANDALONE="standalone-job"
COMMAND_HISTORY_SERVER="history-server"

# If unspecified, the hostname of the container is taken as the JobManager address
JOB_MANAGER_RPC_ADDRESS=${JOB_MANAGER_RPC_ADDRESS:-$(hostname -f)}
CONF_FILE_DIR="${FLINK_HOME}/conf"

check_priv_user() {
    if [ $(id -u) == 0 ]; then
        echo "WARNING: Running as root user is not recommended. Please use a non-root user to run Flink."
    fi
}

copy_plugins_if_required() {
  if [ -z "$ENABLE_BUILT_IN_PLUGINS" ]; then
    return 0
  fi

  echo "Enabling required built-in plugins"
  for target_plugin in $(echo "$ENABLE_BUILT_IN_PLUGINS" | tr ';' ' '); do
    echo "Linking ${target_plugin} to plugin directory"
    plugin_name=${target_plugin%.jar}

    mkdir -p "${FLINK_HOME}/plugins/${plugin_name}"
    if [ ! -e "${FLINK_HOME}/opt/${target_plugin}" ]; then
      echo "Plugin ${target_plugin} does not exist. Exiting."
      exit 1
    else
      ln -fs "${FLINK_HOME}/opt/${target_plugin}" "${FLINK_HOME}/plugins/${plugin_name}"
      echo "Successfully enabled ${target_plugin}"
    fi
  done
}

set_config_options() {
    local config_parser_script="$FLINK_HOME/bin/config-parser-utils.sh"
    local config_dir="$FLINK_HOME/conf"
    local bin_dir="$FLINK_HOME/bin"
    local lib_dir="$FLINK_HOME/lib"

    local config_params=()

    while [ $# -gt 0 ]; do
        local key="$1"
        local value="$2"

        config_params+=("-D${key}=${value}")

        shift 2
    done

    if [ "${#config_params[@]}" -gt 0 ]; then
        "${config_parser_script}" "${config_dir}" "${bin_dir}" "${lib_dir}" "${config_params[@]}"
    fi
}

prepare_configuration() {
    local config_options=()

    config_options+=("jobmanager.rpc.address" "${JOB_MANAGER_RPC_ADDRESS}")
    config_options+=("blob.server.port" "6124")
    config_options+=("query.server.port" "6125")

    if [ -n "${TASK_MANAGER_NUMBER_OF_TASK_SLOTS}" ]; then
        config_options+=("taskmanager.numberOfTaskSlots" "${TASK_MANAGER_NUMBER_OF_TASK_SLOTS}")
    fi

    if [ ${#config_options[@]} -ne 0 ]; then
        set_config_options "${config_options[@]}"
    fi

    if [ -n "${FLINK_PROPERTIES}" ]; then
        process_flink_properties "${FLINK_PROPERTIES}"
    fi
}

process_flink_properties() {
    local flink_properties_content=$1
    local config_options=()

    local OLD_IFS="$IFS"
    IFS=$'\n'
    for prop in $flink_properties_content; do
        prop=$(echo $prop | tr -d '[:space:]')

        if [ -z "$prop" ]; then
            continue
        fi

        IFS=':' read -r key value <<< "$prop"

        value=$(echo $value | envsubst)

        config_options+=("$key" "$value")
    done
    IFS="$OLD_IFS"

    if [ ${#config_options[@]} -ne 0 ]; then
        set_config_options "${config_options[@]}"
    fi
}

# FLINK-39924: jemalloc's default narenas = 4 * ncpus is taken from
# /proc/cpuinfo (host CPU count), ignoring the container's quota
# and idle arenas hold dirty pages until dirty_decay_ms, inflating
# RSS. Derive narenas from the cgroup CPU quota instead.
configure_jemalloc_narenas() {
    case ",${MALLOC_CONF}," in
        *,narenas:*)
            echo "jemalloc: respecting user-supplied narenas in MALLOC_CONF=${MALLOC_CONF}"
            return
            ;;
    esac

    local cpus="" cpu_quota cpu_period
    if [ -r /sys/fs/cgroup/cpu.max ]; then
        # cgroup v2
        read -r cpu_quota cpu_period < /sys/fs/cgroup/cpu.max
        if [ "$cpu_quota" != "max" ] && [ -n "$cpu_period" ] && [ "$cpu_period" -gt 0 ]; then
            cpus=$(( (cpu_quota + cpu_period - 1) / cpu_period ))
        fi
    elif [ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -r /sys/fs/cgroup/cpu/cpu.cfs_period_us ]; then
        # cgroup v1
        cpu_quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)
        cpu_period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)
        if [ "$cpu_quota" -gt 0 ] && [ "$cpu_period" -gt 0 ]; then
            cpus=$(( (cpu_quota + cpu_period - 1) / cpu_period ))
        fi
    fi
    # Fall back to nproc when no quota is set (cpuset-pinned / unlimited).
    if [ -z "$cpus" ] || [ "$cpus" -le 0 ]; then
        cpus=$(nproc 2>/dev/null || echo 1)
    fi

    local narenas
    if [ "$cpus" -le 1 ]; then
        narenas=1
    else
        narenas=$(( cpus * 4 ))
    fi

    if [ -z "${MALLOC_CONF}" ]; then
        export MALLOC_CONF="narenas:${narenas}"
        echo "jemalloc: setting MALLOC_CONF=${MALLOC_CONF} (detected ${cpus} CPUs)"
    else
        export MALLOC_CONF="${MALLOC_CONF},narenas:${narenas}"
        echo "jemalloc: appended narenas, MALLOC_CONF=${MALLOC_CONF} (detected ${cpus} CPUs)"
    fi
}

maybe_enable_jemalloc() {
    if [ "${DISABLE_JEMALLOC:-false}" == "false" ]; then
        JEMALLOC_PATH="/usr/lib/$(uname -m)-linux-gnu/libjemalloc.so"
        JEMALLOC_FALLBACK="/usr/lib/x86_64-linux-gnu/libjemalloc.so"
        if [ -f "$JEMALLOC_PATH" ]; then
            export LD_PRELOAD=$LD_PRELOAD:$JEMALLOC_PATH
        elif [ -f "$JEMALLOC_FALLBACK" ]; then
            export LD_PRELOAD=$LD_PRELOAD:$JEMALLOC_FALLBACK
        else
            if [ "$JEMALLOC_PATH" = "$JEMALLOC_FALLBACK" ]; then
                MSG_PATH=$JEMALLOC_PATH
            else
                MSG_PATH="$JEMALLOC_PATH and $JEMALLOC_FALLBACK"
            fi
            echo "WARNING: attempted to load jemalloc from $MSG_PATH but the library couldn't be found. glibc will be used instead."
            return
        fi

        configure_jemalloc_narenas
    fi
}

check_priv_user

maybe_enable_jemalloc

copy_plugins_if_required

prepare_configuration

args=("$@")
if [ "$1" = "help" ]; then
    printf "Usage: $(basename "$0") (jobmanager|${COMMAND_STANDALONE}|taskmanager|${COMMAND_HISTORY_SERVER})\n"
    printf "    Or $(basename "$0") help\n\n"
    printf "By default, Flink image adopts jemalloc as default memory allocator. This behavior can be disabled by setting the 'DISABLE_JEMALLOC' environment variable to 'true'.\n"
    exit 0
elif [ "$1" = "jobmanager" ]; then
    args=("${args[@]:1}")

    echo "Starting Job Manager"

    exec "$FLINK_HOME/bin/jobmanager.sh" start-foreground "${args[@]}"
elif [ "$1" = ${COMMAND_STANDALONE} ]; then
    args=("${args[@]:1}")

    echo "Starting Job Manager"

    exec "$FLINK_HOME/bin/standalone-job.sh" start-foreground "${args[@]}"
elif [ "$1" = ${COMMAND_HISTORY_SERVER} ]; then
    args=("${args[@]:1}")

    echo "Starting History Server"

    exec "$FLINK_HOME/bin/historyserver.sh" start-foreground "${args[@]}"
elif [ "$1" = "taskmanager" ]; then
    args=("${args[@]:1}")

    echo "Starting Task Manager"

    exec "$FLINK_HOME/bin/taskmanager.sh" start-foreground "${args[@]}"
fi

args=("${args[@]}")

# Running command in pass-through mode
exec "${args[@]}"
