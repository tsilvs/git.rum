#!/bin/bash

# lib.param

. ./var.sh

params_parse() {
	# '.[].id'
	# ".[] | select(.id == \"$param_id\")"
	local params_j="$1"
	local params_i18n_j="$2"
	local params_c="$3"
	local params_parsed_j=''
	#prop_get "$params_j" '.[]'
	#prop_get "$params_j" '.[].id'
	#prop_get "$params_j" '.[] | select(.id == "$param_id")'
	#prop_get "$params_j" '.[] | select(.id == "$param_id") | .id'
	#prop_get "$params_j" '.[] | select(.id == "$param_id") | .name'
	#prop_get "$params_j" '.[] | select(.id == "$param_id") | .def'
	#long_opt="--$param_name"
	#short_opt="-${param_name,,}"
	#if [[ "$param_name" == "$long_opt" || "$parma_name" == "$short_opt" ]]; then
	#	eval "${param_key}=\"$value\""
	#	break
	#fi
	#	[[ "$key" == "-h" || "$key" == "--help" ]] && show_usage && exit 0
	
	#prop_get "$params_j" '' | while read -r param; do
	#	params_out_j+="\"$param\": \"$(read_input "$(prop_get "$params_i18n_j" ".[] | select(.id == \"$param\") | .prompt")" "$(prop_get "$params_j" ".[] | select(.id == \"$param\") | .def")")}\",\n"
	#done
	
	params_parsed_j+='[\n'
	#loop through params
		params_parsed_j+="
		{
			\"id\": \"$param_id\",
			\"val\": \"$param_val\"
		},
		"
	#end loop
	params_parsed_j+=']'
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
		print_list+="  ${names[$key]}\t${descr[$key]}\n"
		(( l < ${#names[$key]} )) && l=${#names[$key]}
	done
	IFS=$IFSB
	local tab_stop
	tab_stop=$(tabs -d | awk -F "tabs " 'NR==1{ print $2 }')
	tabs $((l + 1))
	echo -e "$print_list"
	tabs "$tab_stop"
}

read_input() {
	local prompt="$1"
	local default="$2"
	local input
	read -rp "$prompt [$default]: " input
	echo "${input:-$default}"
}

read_all_inputs() {
	local params_j="$1"
	local params_i18n_j="$2"
	local params_out_j=''
	local param_id=''
	local param_def=''
	local param_prt=''
	params_out_j+='[\n'
	prop_get "$params_j" '.[]' | while read -r param; do
		param_id="$(prop_get "$param" '.id')"
		param_def="$(prop_get "$param" '.def')"
		param_prt="$(prop_get "$params_i18n_j" ".[] | select(.id == \"$param_id\") | .prompt")"
		params_out_j+="
		{
			\"id\": \"$param_id\",
			\"val\": \"$(read_input "$param_prt" "$param_def")\"
		},
		"
	done
	params_out_j+=']'
	echo $params_out_j
}

