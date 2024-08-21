#!/bin/bash

# lib.param

. ./var.sh

read_input() {
	local prompt="$1"
	local default="$2"
	local input
	read -rp "$prompt [$default]: " input
	echo "${input:-$default}"
}

params_parse() {
	local params_j="$1"
	local params_i18n_j="$2"
	local params_c="$3"
	local params_parsed_j='[\n'

	prop_get "$params_j" '.[]' | while read -r param; do
		local param_id=$(prop_get "$param" '.id')
		local param_name=$(prop_get "$param" '.name')
		local param_def=$(prop_get "$param" '.def')
		local param_prompt=$(prop_get "$params_i18n_j" ".[] | select(.id == \"$param_id\") | .prompt")
		local param_val=""

		for p in "${params_c[@]}"; do
			local name="${p%%=*}"
			local value="${p#*=}"
			name="${name#--}"
			if [[ "$name" == "$param_name" ]]; then
				param_val="$value"
				break
			fi
		done

		[[ -z "$param_val" ]] && param_val=$(read_input "$param_prompt" "$param_def")

		params_parsed_j+="
		{
			\"id\": \"$param_id\",
			\"val\": \"$param_val\"
		},"
	done

	params_parsed_j=${params_parsed_j%,}
	params_parsed_j+='\n]'

	echo "$params_parsed_j"
}

params_print() {
	local -n names=$1
	local -n descr=$2
	local print_list=""
	local l=0
	local IFSB=$IFS
	IFS=$'\n'
	for key in "${!names[@]}"; do
		print_list+="	${names[$key]}\t${descr[$key]}\n"
		(( l < ${#names[$key]} )) && l=${#names[$key]}
	done
	IFS=$IFSB
	local tab_stop
	tab_stop=$(tabs -d | awk -F "tabs " 'NR==1{ print $2 }')
	tabs $((l + 1))
	echo -e "$print_list"
	tabs "$tab_stop"
}