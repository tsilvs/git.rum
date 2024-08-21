#!/bin/bash

. ./lib/var.sh

. ./lib/net.sh

. ./lib/param.sh

repo_check() {
	local i18n_repo_j="$1"
	local repo_dir="$2"
	if [ ! -d "$repo_dir/.git" ]; then
		echo "'$repo_dir': $(prop_get "$i18n_repo_j" '.not')"
		exit 1
	fi
}

repo_rem_add() {
	local repo_dir="$1"
	local remote_name="$2"
	local url="$3"
	if git -C "$repo_dir" remote get-url "$remote_name" &>/dev/null; then
		echo "'$repo_dir' '$remote_name': $(prop_get "$i18n_rem_j" '.ex')"
		return 1
	fi
	git -C "$repo_dir" remote add "$remote_name" "$url"
}

repo_rem_push() {
	local repo_dir="$1"
	local remote_name="$2"
	local branch="$3"
	git -C "$repo_dir" push "$remote_name" "$branch"
}

repo_check_on_server() {
	local i18n_api_j="$1"
	local api_j="$2"

	local curl_headers=()
	for header in "${headers[@]}"; do
		curl_headers+=(-H "$header")
	done
	
	local resp
	resp=$(curl -s "${curl_headers[@]}" "$url")
	local repo_exists
	# repo_exists=
	# $(prop_get "$resp" ".[] | select(.name == \"$repo_name\")")
	# > /dev/null

	if $repo_exists; then
		echo "'$repo_name': Repository already exists on the server."
		return 0
	fi
	return 1
}

prompt_to_go() {
	local i18n_prt_j="$1"
	while true; do
		read -rp "$(prop_get "$i18n_prt_j" ".cfm") (y/n): " confirm
		case $confirm in
			y|Y) break ;;
			n|N) echo "$(prop_get "$i18n_prt_j" ".cnc")"; exit 1 ;;
			*) echo "$(prop_get "$i18n_prt_j" ".err")" ;;
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
	local i18n="$(cat "$script_root/i18n.json")"
	local i18nl="$(prop_get "$i18n" ".$lang")"
	local api_j="$(cat "$script_root/api.json")"
	local params_j="$(cat "$script_root/params.json")"

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
	local params_subed_j=$(rephs "$params_j" "$subs")
	local params_work_j=$(params_parse "$params_subed_j" "$i18nl" "${params_c[@]}")

	prop_get "$i18nl" ".val.rev" # Prompt for value revision
	params_print "$params_work_j" # Print current values
	prompt_to_go "$(prop_get "$i18nl" ".prt")" # Prompt for action confirmation

	prop_get "$api_j" '.[]' | while read -r api; do
	
		prov=$(prop_get "$api" '.prov')
		url=$(prop_get "$api" '.url')
		data=$(prop_get "$api" '.data')
		headers=$(prop_get "$api" '.headers[]')
		url=$(rephs "$url" repo_conf_values)
		data=$(rephs "$data" repo_conf_values)
		headers=($(rephs "${headers[@]}" repo_conf_values))

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