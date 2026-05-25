#!/bin/bash
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Returns the HTTP status code from a call
# usage: get_http_response_code url username password
function get_http_response_code() {
    url=$1
    if [ -z "$url" ]; then
        echo "Error: you need to specify the URL for get the HTTP response"
        exit 1
    fi
    username=$2
    password=$3

    if [ -z "$username" ] || [ -z "$password" ]; then
        result=$(curl -LI "$url" -o /dev/null -w '%{http_code}\n' -s)
    else
        result=$(curl -LI -u "$username":"$password" "$url" -o /dev/null -w '%{http_code}\n' -s)
    fi

    echo "$result"
}

# Login to Kibana using username and password
# usage: login_kibana url username password
function login_kibana() {
    url=$1
    if [ -z "$url" ]; then
        echo "Error: you need to specify the URL for login to Kibana"
        exit 1
    fi
    username=$2
    password=$3
    if [ -z "$username" ] || [ -z "$password" ]; then
        echo "Error: you need to specify username and password to login to Kibana"
        exit 1
    fi

    result=$(curl -X POST \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: reporting" \
        -H "x-elastic-internal-origin: Kibana" \
        -d '{"providerType":"basic","providerName":"basic","currentURL":"'"$url"'/login?next=%2F","params":{"username":"'"$username"'","password":"'"$password"'"}}' \
        "${url}/internal/security/login" \
        -o /dev/null \
        -w '%{http_code}\n' -s)

    echo "$result"
}

# Tee the output in a file
function cap () { tee "${1}/capture.out"; }

# Return the previous output
function ret () { cat "${1}/capture.out"; }

# Shared debug log — same file that start.sh writes to, dumped by the CI
# "Dump start.sh debug log" step (if: always()) so entries survive cancellation.
_UTILITY_DEBUG_LOG=/tmp/start-local-debug.log
_ulog() { echo "[$(date '+%T')] [utility] $*" >> "$_UTILITY_DEBUG_LOG"; }

# Check if a container service is running
function check_container_service_running() {
  local container_name=$1
  local containers ps_exit
  _ulog "check_container_service_running('${container_name}'): running timeout 30 ${TEST_CONTAINER_CLI} ps ..."
  containers=$(timeout 30 $TEST_CONTAINER_CLI ps --format '{{.Names}}' 2>/dev/null)
  ps_exit=$?
  if [ "${ps_exit}" -eq 124 ]; then
    _ulog "check_container_service_running('${container_name}'): TIMED OUT (exit 124 — timeout(30) fired; '${TEST_CONTAINER_CLI} ps' was the hang point)."
    return 1
  fi
  _ulog "check_container_service_running('${container_name}'): ps done (exit ${ps_exit})."
  if echo "$containers" | grep -q "^${container_name}$"; then
    return 0 # true
  else
    return 1 # false
  fi
}

# Check if a container image exists
function check_container_image_exists() {
  local image_name=$1
  local inspect_exit
  _ulog "check_container_image_exists('${image_name}'): running timeout 30 ${TEST_CONTAINER_CLI} image inspect ..."
  timeout 30 $TEST_CONTAINER_CLI image inspect "$image_name" > /dev/null 2>&1
  inspect_exit=$?
  if [ "${inspect_exit}" -eq 124 ]; then
    _ulog "check_container_image_exists('${image_name}'): TIMED OUT (exit 124 — timeout(30) fired; '${TEST_CONTAINER_CLI} image inspect' was the hang point)."
    return 1
  fi
  _ulog "check_container_image_exists('${image_name}'): inspect done (exit ${inspect_exit})."
  if [ "${inspect_exit}" -eq 0 ]; then
    return 0 # true
  else
    return 1 # false
  fi
}
