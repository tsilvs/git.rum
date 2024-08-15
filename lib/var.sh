#!/bin/bash

# lib.var

prop_get() {
	local response="$1"
	local property="$2"
	echo "$response" | jq -r "$property"
}

replace() {
	local data="$1"
	local match="$2"
	local replace="$3"
	echo "${data//$match/$replace}"
}
