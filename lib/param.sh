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

read_all_inputs() {
	local params_json="$1"
	local params_i18n_json="$2"
	local params_out_json=''
	params_out_json+='{\n'
	prop_get "$params_json" 'keys_unsorted' | while read -r param; do
		params_out_json+="\"$param\": \"$(read_input "$(prop_get "$params_i18n_json" ".[] | select(.id == \"$param\") | .prompt")" "$(prop_get "$params_json" ".[] | select(.id == \"$param\") | .def")")}\",\n"
	done
	params_out_json+='}'
	echo $params_out_json
}

params_parse() {
	# '.[].id'
	# ".[] | select(.id == \"$param_id\")"
	
	local params_json="$1"
	local params_i18n_json="$2"
	#local param_names=$(prop_get "$params_json" '.[].id')
	#local params=$(prop_get "$params_json" '.[]')
	#readarray -t param_lines <<<"$param_names"
	#local param_num=${#param_lines[@]}

	#for param_line in $param_lines; do
	#	key="$1"
	#	value="$2"
	#	shift 2

	#	for param_key in "${!param_names[@]}"; do
	#		long_opt="--$()"
	#		short_opt="-${param_key,,}" # Convert key to lowercase for short option
	#		if [[ "$key" == "$long_opt" || "$key" == "$short_opt" ]]; then
	#			eval "${param_key}=\"$value\""
	#			break
	#		fi
	#	done

	#	if [[ "$key" == "-h" || "$key" == "--help" ]]; then
	#		show_usage
	#		exit 0
	#	fi
	#done
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
