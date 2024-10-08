#!/bin/bash

# lib.var

prop_get() {
	local json="$1"
	local prop="$2"
	#echo "$json" | jq -r "$prop"
	echo "$json" | jq -R -s "fromjson | . | $prop"
}

rephs() {
	local str="$1"
	declare -n params="$2"

	for key in "${!params[@]}"; do
		local placeholder="{{${key}}}"
		local value="${params[$key]}"
		str="${str//$placeholder/$value}"
	done

	echo "$str"
}
