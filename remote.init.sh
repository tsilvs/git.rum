#!/bin/bash

# Default values
DEFAULT_OWNER="$(id -un)"
#DEFAULT_REPO="repo-$(uuidgen | awk -F '-' '{ print $5 }')"
DEFAULT_REPO="${PWD##*/}"
DEFAULT_DESCR="This is a repo for $DEFAULT_OWNER/$DEFAULT_REPO project"
DEFAULT_BRANCH="main"
DEFAULT_PRIVATE="false"
DEFAULT_VISIBILITY="public"

read_input() {
	local prompt="$1"
	local default="$2"
	local input
	read -p "$prompt [$default]: " input
	echo "${input:-$default}"
}

repo_rem_url_get() {
	local response="$1"
	local property="$2"
	echo "$response" | jq -r "$property"
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

check_git_repo() {
	local repo_dir="$1"
	if [ ! -d "$repo_dir/.git" ]; then
		echo "'$repo_dir' is not a Git repository."
		exit 1
	fi
}

check_repo_exists_on_server() {
	local repo_name="$1"
	local token="$2"
	local provider="$3"
	local url

	case "$provider" in
		gh)
			url="https://api.github.com/user/repos"
			;;
		gl)
			url="https://gitlab.com/api/v4/projects?search=$repo_name"
			;;
		cb)
			url="https://codeberg.org/api/v1/user/repos"
			;;
		*)
			echo "Unknown provider: $provider"
			return 1
			;;
	esac

	if curl -s -H "Authorization: token $token" "$url" | jq -e ".[] | select(.name == \"$repo_name\")" > /dev/null; then
		echo "Repository '$repo_name' already exists on $provider."
		return 0  # Return 0 to indicate that the repo exists
	fi
	return 1  # Return 1 to indicate that the repo does not exist
}

declare -A repo_conf_labels
repo_conf_labels+=( ["OWNER"]="Owner" ["REPO"]="Repo Name" ["DESCR"]="Repo Description" ["TOKEN_GH"]="Token @ GitHub" ["TOKEN_GL"]="Token @ GitLab" ["TOKEN_CB"]="Token @ Codeberg" ["REPO_DIR"]="Repository Directory" )

params_print() {
	local -n names=$1
	local -n descr=$2
	local print_list=""
	local l=0
	local IFSB=$IFS
	IFS=$'\n'
	for ((i=0; i<${#names[@]}; i++)); do
		print_list+="${names[$i]}\t${descr[$i]}\n"
		(( l < ${#names[$i]} )) && l=${#names[$i]}
	done
	IFS=$IFSB
	local tab_stop
	tab_stop=$(tabs -d | awk -F "tabs " 'NR==1{ print $2 }')
	tabs $(($l + 1))
	echo -e "$print_list"
	tabs $tab_stop
}

read_all_inputs() {
	OWNER="${1:-$DEFAULT_OWNER}"
	REPO="${2:-$DEFAULT_REPO}"
	DESCR="${3:-$DEFAULT_DESCR}"
	BRANCH="${4:-$DEFAULT_BRANCH}"
	PRIVATE="${5:-$DEFAULT_PRIVATE}"
	VISIBILITY="${6:-$DEFAULT_VISIBILITY}"
	TOKEN_GH="${7:-}"
	TOKEN_GL="${8:-}"
	TOKEN_CB="${9:-}"
	REPO_DIR="${10:-$(pwd)}"
}

prompt_to_go() {
	local max_attempts=${1:-0}  # Default to 0 for unlimited attempts
	local attempts=0

	while true; do
		read -p "Do you want to proceed? (y/n): " confirm

		if [[ $confirm == "y" || $confirm == "n" ]]; then
			break
		else
			echo "Invalid input. Please enter 'y' or 'n'."
		fi

		((attempts++))

		if ((max_attempts > 0 && attempts >= max_attempts)); then
			echo "Maximum attempts reached. Operation canceled."
			exit 1
		fi
	done

	if [[ $confirm != "y" ]]; then
		echo "Operation canceled."
		exit 1
	fi
}

show_usage() {
	declare -A param_names=(
		["REPO_DIR"]="repository_directory"
		["OWNER"]="owner"
		["REPO"]="repo_name"
		["DESCR"]="description"
		["BR"]="branch"
		["TOKEN_GH"]="github_token"
		["TOKEN_GL"]="gitlab_token"
		["TOKEN_CB"]="codeberg_token"
	)

	declare -A param_descr=(
		["REPO_DIR"]="Path to the local Git repository."
		["OWNER"]="Owner of the repository (default: current user)."
		["REPO"]="Name of the repository (default: current directory name)."
		["DESCR"]="Description of the repository (default: generated description)."
		["BR"]="Branch name to push to (default: 'main')."
		["TOKEN_GH"]="GitHub access token."
		["TOKEN_GL"]="GitLab access token."
		["TOKEN_CB"]="Codeberg access token."
	)
	
	echo "Usage: $0 <repository_directory> [owner] [repo_name] [description] [branch] [github_token] [gitlab_token] [codeberg_token]"
	echo
	echo "Parameters:"
	params_print param_names param_descr
	echo "Options:"
	echo "  -h, --help             Show this help message and exit."
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

remote_create() {
	local url="$1"
	local data="$2"
	shift 2
	local headers=("$@")

	local curl_headers=()
	for header in "${headers[@]}"; do
		curl_headers+=(-H "$header")
	done

	if check_repo_exists_on_server "$repo_name" "$token" "$provider"; then
		echo "Skipping creation on $provider as the repository already exists."
		return
	fi

	curl -X POST "${curl_headers[@]}" -d "$data" "$url"

	if [[ $? -ne 0 ]]; then
		echo "Error creating repository on $provider."
		return 1
	fi

	echo "Repository '$repo_name' created on $provider."
}

main() {
	# Check for help flag
	if [[ "$1" == "-h" || "$1" == "--help" ]]; then
		show_usage
		exit 0
	fi

	if [ $# -eq 0 ]; then
		REPO_DIR="$(pwd)"  # Set to current directory
	else
		REPO_DIR="$1"  # Use the first argument if provided
	fi

	check_git_repo "$REPO_DIR"

	read_all_inputs "$@"

	declare -A repo_conf_values=( ["OWNER"]="$OWNER" ["REPO"]="$REPO" ["DESCR"]="$DESCR" ["TOKEN_GH"]="$TOKEN_GH" ["TOKEN_GL"]="$TOKEN_GL" ["TOKEN_CB"]="$TOKEN_CB" ["REPO_DIR"]="$REPO_DIR" ["PRIVATE"]="false" ["VISIBILITY"]="public" )

	echo "Please review before applying:"
	params_print repo_conf_labels repo_conf_values
	prompt_to_go

	config_file="remote_repo_conf.json"

	jq -c '.[]' "$config_file" | while read -r config; do
		prov=$(echo "$config" | jq -r '.prov')
		url=$(echo "$config" | jq -r '.url')
		data=$(echo "$config" | jq -r '.data')
		headers=$(echo "$config" | jq -r '.headers[]')

		# Replace placeholders in data and headers
		url=$(rephs "$url" repo_conf_values)
		data=$(rephs "$data" repo_conf_values)
		headers=($(rephs "${headers[@]}" repo_conf_values))

		remote_create "$url" "$data" "${headers[@]}"
	done

	provs=("gh" "gl" "cb")
	declare -A prov_url_props=( [gh]=".ssh_url" [gl]=".ssh_url_to_repo" [cb]=".ssh_url" )
	declare -A tokens=( [gh]="$TOKEN_GH" [gl]="$TOKEN_GL" [cb]="$TOKEN_CB" )
	
	for i in "${!provs[@]}"; do
		[ ! check_repo_exists_on_server "$REPO" "${tokens[$i]}" "${provs[$i]}" ] && create_repo "${provs[$i]}" "$REPO" "$DESCR" "${tokens[$i]}"
	done

	for provider in "${provs[@]}"; do
		repo_rem_add "$REPO_DIR" "$provider" "$(repo_rem_url_get "$REPO" ".ssh_url")" || exit 1
		repo_rem_push "$REPO_DIR" "$provider" "$BRANCH"
	done
}

main "$@"
