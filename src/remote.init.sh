#!/bin/bash

. ../libsh/var.sh

. ../libsh/net.sh

. ../libsh/param.sh

. ../libgit/repo.sh

prompt_to_go() {
	local i18n_prt_j="$1"
	while true; do
		read -rp "$(prop_get "$i18n_prt_j" ".cfm") (y/n): " confirm
		case $confirm in
			y|Y) break ;;
			n|N) prop_get "$i18n_prt_j" ".cnc"; exit 1 ;;
			*) prop_get "$i18n_prt_j" ".err" ;;
		esac
	done
}

show_usage() {
	echo "Usage: $0 [options]"
	echo
	echo "Options:"
	
	# params_print param_names param_descr
	
	echo "  -h, --help			 Show this help message and exit."
}

remote_create() {
	local url="$1"
	local data="$2"
	shift 2
	local headers=("$@")

	local curl_headers=()
	for header in "${headers[@]}"; do
		curl_headers+=(-H "$header")
	done

	local resp
	resp=$(curl -X POST "${curl_headers[@]}" -d "$data" "$url")

	if ! resp; then
		echo "Error creating repository."
		return 1
	fi

	echo "Repository created."
}

main() {
	local lang="en"
	local script_root="${0%/*}"
	local i18n
	i18n="$(cat "$script_root/../dat/i18n.json")"
	local i18nl
	i18nl="$(prop_get "$i18n" ".$lang")"
	local api_j
	api_j="$(cat "$script_root/../dat/api.json")"
	local params_j
	params_j="$(cat "$script_root/../dat/params.json")"

	for arg in "$@"; do
		if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
			show_usage
			exit 0
		fi
	done

	declare -A subs=(
		[CUR_REPO_DIR]=""
		[CUR_USER]="$(id -un)"
		[CUR_REPO]="${PWD##*/}"
		[I18N_REPO_DESCR]=""
	)

	local params_c=("$@")
	local params_sub_j
	params_sub_j=$(rephs "$params_j" "${subs[@]}")
	local params_work_j
	params_work_j=$(params_parse "$params_sub_j" "$i18nl" "${params_c[@]}")

	prop_get "$i18nl" ".val.rev" # Prompt for value revision
	params_print "$params_work_j" # Print current values
	prompt_to_go "$(prop_get "$i18nl" ".prt")" # Prompt for action confirmation

	prop_get "$api_j" '.[]' | while read -r api; do
		local prov
		prov=$(prop_get "$api" '.prov')
		local url
		url=$(rephs "$(prop_get "$api" '.url')" repo_conf_values)
		local data
		data=$(rephs "$(prop_get "$api" '.data')" repo_conf_values)
		local headers_j
		headers_j=$(rephs "$(prop_get "$api" '.headers[]')" repo_conf_values)

		if ! repo_check_on_server "$REPO" "${tokens[$prov]}" "$url" "${headers[@]}"; then
			remote_create "$url" "$data" "${headers[@]}"
		else
			echo "$prov: $(prop_get "$i18nl" '.repo.skip')"
		fi
	done

	provs=("gh" "gl" "cb")
	declare -A prov_url_props=(
		[gh]=".ssh_url"
		[gl]=".ssh_url_to_repo"
		[cb]=".ssh_url"
	)
	declare -A tokens=(
		[gh]="$TOKEN_GH"
		[gl]="$TOKEN_GL"
		[cb]="$TOKEN_CB"
	)

	for provider in "${provs[@]}"; do
		repo_rem_add "$REPO_DIR" "$provider" "$(prop_get "$REPO" "${prov_url_props[$provider]}")" || exit 1
		repo_rem_push "$REPO_DIR" "$provider" "$BRANCH"
	done
}

main "$@"
