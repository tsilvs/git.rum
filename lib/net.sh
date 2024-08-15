#!/bin/bash

# lib.net

call_curl() {
	local api_url=$1
	local headers=$2
	local res_path=$3
	local resp=$(curl -s "${headers[@]}" -o /dev/null -w "%{http_code}" "${api_url}${res_path}")
	echo $resp
}

http_code_get() {
	local resp=$1
	echo "$(echo "$response" | tail -n1)"
}
