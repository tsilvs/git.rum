#!/bin/bash

. ./lib/var.sh

. ./lib/net.sh

. ./lib/param.sh

read_all_inputs() {
	OWNER="${OWNER:-$(read_input 'Enter owner' "$DEFAULT_OWNER")}"
	REPO="${REPO:-$(read_input 'Enter repo name' "$DEFAULT_REPO")}"
	DESCR="${DESCR:-$(read_input 'Enter repo description' "$DEFAULT_DESCR")}"
	BRANCH="${BRANCH:-$(read_input 'Enter branch name' "$DEFAULT_BRANCH")}"
	PRIVATE="${PRIVATE:-$(read_input 'Is the repo private?' "$DEFAULT_PRIVATE")}"
	VISIBILITY="${VISIBILITY:-$(read_input 'Enter visibility' "$DEFAULT_VISIBILITY")}"
	TOKEN_GH="${TOKEN_GH:-$(read_input 'Enter GitHub token' "")}"
	TOKEN_GL="${TOKEN_GL:-$(read_input 'Enter GitLab token' "")}"
	TOKEN_CB="${TOKEN_CB:-$(read_input 'Enter Codeberg token' "")}"
	REPO_DIR="${REPO_DIR:-$(read_input 'Enter repository directory' "$(pwd)")}"
}

repo_rem_add() {
	local repo_dir="$1"
	local remote_name="$2"
	local url="$3"
	if git -C "$repo_dir" remote get-url "$remote_name" &>/dev/null; then
		echo "Remote '$remote_name' already exists in '$repo_dir'."
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

repo_check() {
	local repo_dir="$1"
	if [ ! -d "$repo_dir/.git" ]; then
		echo "'$repo_dir' is not a Git repository."
		exit 1
	fi
}

repo_check_on_server() {
	local repo_name="$1"
	local token="$2"
	local url="$3"
	local headers=("${@:4}")

	local curl_headers=()
	for header in "${headers[@]}"; do
		curl_headers+=(-H "$header")
	done
	
	local resp
	resp=$(curl -s "${curl_headers[@]}" "$url")
	local repo_exists
	repo_exists=prop_get "$resp" ".[] | select(.name == \"$repo_name\")" > /dev/null

	if $repo_exists; then
		echo "Repository '$repo_name' already exists on the server."
		return 0
	fi
	return 1
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

prompt_to_go() {
	while true; do
		read -rp "Do you want to proceed? (y/n): " confirm
		case $confirm in
			y|Y) break ;;
			n|N) echo "Operation canceled."; exit 1 ;;
			*) echo "Invalid input. Please enter 'y' or 'n'." ;;
		esac
	done
}

show_usage() {
	echo "Usage: $0 [options]"
	echo
	echo "Options:"
	params_print param_names param_descr
	echo "  -h, --help             Show this help message and exit."
}

parse_arguments() {
	while [[ $# -gt 0 ]]; do
		key="$1"
		value="$2"
		shift 2

		for param_key in "${!param_names[@]}"; do
			long_opt="--${param_names[$param_key]}"
			short_opt="-${param_key,,}" # Convert key to lowercase for short option

			if [[ "$key" == "$long_opt" || "$key" == "$short_opt" ]]; then
				eval "${param_key}=\"$value\""
				break
			fi
		done

		if [[ "$key" == "-h" || "$key" == "--help" ]]; then
			show_usage
			exit 0
		fi
	done
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

	# Default values
	local DEFAULT_OWNER
	local DEFAULT_REPO
	local DEFAULT_DESCR
	local DEFAULT_BRANCH
	local DEFAULT_PRIVATE
	local DEFAULT_VISIBILITY
	
	DEFAULT_OWNER="$(id -un)"
	#DEFAULT_REPO="repo-$(uuidgen | awk -F '-' '{ print $5 }')"
	DEFAULT_REPO="${PWD##*/}"
	DEFAULT_DESCR="This is a repo for $DEFAULT_OWNER/$DEFAULT_REPO project"
	DEFAULT_BRANCH="main"
	DEFAULT_PRIVATE="false"
	DEFAULT_VISIBILITY="public"
	
	local i18n='{
		"en": {
			"repo": {
				"err": "Error creating repository.",
				"succ": "Repository created."
			},
			"val": {
				"rev": "Please review before applying:"
			},
			"params": {
				"prompts": {
					"OWNER": "Enter owner",
					"REPO": "Enter repo name",
					"DESCR": "Enter repo description",
					"BRANCH": "Enter branch name",
					"PRIVATE": "Is the repo private?",
					"VISIBILITY": "Enter visibility",
					"TOKEN_GH": "Enter GitHub token",
					"TOKEN_GL": "Enter GitLab token",
					"TOKEN_CB": "Enter Codeberg token",
					"REPO_DIR": "Enter repository directory"
				}
			}
		}
	}'

	local config_json='[
		{
			"prov": "gh",
			"url": "https://api.github.com/user/repos",
			"headers": ["Authorization: token {{TOKEN}}", "Accept: application/vnd.github.v3+json"],
			"data": "{\"name\":\"{{REPO_NAME}}\", \"description\":\"{{DESCRIPTION}}\", \"private\":{{PRIVATE}}}"
		},
		{
			"prov": "gl",
			"url": "https://gitlab.com/api/v4/projects",
			"headers": ["PRIVATE-TOKEN: {{TOKEN}}"],
			"data": "name={{REPO_NAME}}&description={{DESCRIPTION}}&visibility={{VISIBILITY}}"
		},
		{
			"prov": "cb",
			"url": "https://codeberg.org/api/v1/user/repos",
			"headers": ["Authorization: token {{TOKEN}}", "Content-Type: application/json"],
			"data": "{\"name\":\"{{REPO_NAME}}\", \"description\":\"{{DESCRIPTION}}\", \"private\":{{PRIVATE}}}"
		}
	]'

	declare -A param_names=(
		["REPO_DIR"]="repo_dir"
		["OWNER"]="owner"
		["REPO"]="repo_name"
		["DESCR"]="description"
		["BRANCH"]="branch"
		["TOKEN_GH"]="github_token"
		["TOKEN_GL"]="gitlab_token"
		["TOKEN_CB"]="codeberg_token"
	)

	declare -A param_labels=(
		["REPO_DIR"]="Repository Directory"
		["OWNER"]="Owner"
		["REPO"]="Repo Name"
		["DESCR"]="Repo Description"
		["BRANCH"]="Branch"
		["TOKEN_GH"]="Token @ GitHub"
		["TOKEN_GL"]="Token @ GitLab"
		["TOKEN_CB"]="Token @ Codeberg"
	)

	declare -A param_descr=(
		["REPO_DIR"]="Path to the local Git repository."
		["OWNER"]="Owner of the repository (default: current user)."
		["REPO"]="Name of the repository (default: current directory name)."
		["DESCR"]="Description of the repository (default: generated description)."
		["BRANCH"]="Branch name to push to (default: 'main')."
		["TOKEN_GH"]="GitHub access token."
		["TOKEN_GL"]="GitLab access token."
		["TOKEN_CB"]="Codeberg access token."
	)

	if [[ "$1" == "-h" || "$1" == "--help" ]]; then
		show_usage
		exit 0
	fi

	parse_arguments "$@"

	read_all_inputs

	declare -A repo_conf_values=(
		["OWNER"]="$OWNER"
		["REPO"]="$REPO"
		["DESCR"]="$DESCR"
		["TOKEN_GH"]="$TOKEN_GH"
		["TOKEN_GL"]="$TOKEN_GL"
		["TOKEN_CB"]="$TOKEN_CB"
		["REPO_DIR"]="$REPO_DIR"
		["PRIVATE"]="$PRIVATE"
		["VISIBILITY"]="$VISIBILITY"
	)

	prop_get "$i18n" ".$lang.val.rev"
	params_print param_labels repo_conf_values
	prompt_to_go

	prop_get "$config_json" '.[]' | while read -r config; do
		prov=$(prop_get "$config" '.prov')
		url=$(prop_get "$config" '.url')
		data=$(prop_get "$config" '.data')
		headers=$(prop_get "$config" '.headers[]')
		url=$(rephs "$url" repo_conf_values)
		data=$(rephs "$data" repo_conf_values)
		headers=($(rephs "${headers[@]}" repo_conf_values))

		if ! repo_check_on_server "$REPO" "${tokens[$prov]}" "$url" "${headers[@]}"; then
			remote_create "$url" "$data" "${headers[@]}"
		else
			echo "Skipping creation on $prov as the repository already exists."
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
