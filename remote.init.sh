#!/bin/bash

# Default values
DEFAULT_OWNER="$(id -un)"
#DEFAULT_REPO="repo-$(uuidgen | awk -F '-' '{ print $5 }')"
DEFAULT_REPO="${PWD##*/}"
DEFAULT_DESCR="This is a repo for $DEFAULT_OWNER/$DEFAULT_REPO project"
DEFAULT_BRANCH="main"

read_input() {
	local prompt="$1"
	local default="$2"
	local input
	read -p "$prompt [$default]: " input
	echo "${input:-$default}"
}

create_repo_gh() {
	local repo_name="$1"
	local description="$2"
	local token="$3"
	curl -X POST \
		-H "Authorization: token $token" \
		-H "Accept: application/vnd.github.v3+json" \
		-d "{\"name\":\"$repo_name\", \"description\":\"$description\", \"private\":false}" \
		"https://api.github.com/user/repos"
}

create_repo_gl() {
	local repo_name="$1"
	local description="$2"
	local token="$3"
	curl -X POST \
		-H "PRIVATE-TOKEN: $token" \
		-d "name=$repo_name&description=$description" \
		"https://gitlab.com/api/v4/projects"
}

create_repo_cb() {
	local repo_name="$1"
	local description="$2"
	local token="$3"
	curl -X POST \
		-H "Authorization: token $token" \
		-H "Content-Type: application/json" \
		-d "{\"name\":\"$repo_name\", \"description\":\"$description\", \"private\":false}" \
		"https://codeberg.org/api/v1/user/repos"
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
repo_conf_labels+=( ["OWNER"]="Owner" ["REPO"]="Repo Name" ["DESCR"]="Repo Description" ["MYTOKEN_GH"]="Token @ GitHub" ["MYTOKEN_GL"]="Token @ GitLab" ["MYTOKEN_CB"]="Token @ Codeberg" ["REPO_DIR"]="Repository Directory" )

params_print() {
	local -n param_labels=$1
	local -n param_values=$2
	local print_list=""
	local l=0
	local IFSB=$IFS
	IFS=$'\n'
	for key in "${!param_labels[@]}"; do
		print_list+="${param_labels[$key]}\t${param_values[$key]}\n"
		(( l < ${#repo_conf_labels[$key]} )) && l=${#repo_conf_labels[$key]}
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
	TOKEN_GH="${5:-}"
	TOKEN_GL="${6:-}"
	TOKEN_CB="${7:-}"
	REPO_DIR="${8:-$(pwd)}"
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

main() {
	# Check if a directory is passed as an argument
	if [ $# -lt 1 ]; then
		echo "Usage: $0 <repository_directory> [owner] [repo_name] [description] [branch] [github_token] [gitlab_token] [codeberg_token]"
		exit 1
	fi

	REPO_DIR="$1"
	check_git_repo "$REPO_DIR"

	# Read all inputs from command-line arguments
	read_all_inputs "$@"

	declare -A repo_conf_values
	repo_conf_values=( ["OWNER"]="$OWNER" ["REPO"]="$REPO" ["DESCR"]="$DESCR" ["MYTOKEN_GH"]="$TOKEN_GH" ["MYTOKEN_GL"]="$TOKEN_GL" ["MYTOKEN_CB"]="$TOKEN_CB" ["REPO_DIR"]="$REPO_DIR" )

	echo "Please review before applying:"
	params_print repo_conf_labels repo_conf_values
	prompt_to_go

	local resp_gh
	local resp_gl
	local resp_cb

	# Check if repo exists on GitHub
	if ! check_repo_exists_on_server "$REPO" "$TOKEN_GH" "gh"; then
		resp_gh=$(create_repo_gh "$REPO" "$DESCR" "$TOKEN_GH")
	else
		echo "Skipping creation on GitHub as the repository already exists."
	fi

	# Check if repo exists on GitLab
	if ! check_repo_exists_on_server "$REPO" "$TOKEN_GL" "gl"; then
		resp_gl=$(create_repo_gl "$REPO" "$DESCR" "$TOKEN_GL")
	else
		echo "Skipping creation on GitLab as the repository already exists."
	fi

	# Check if repo exists on Codeberg
	if ! check_repo_exists_on_server "$REPO" "$TOKEN_CB" "cb"; then
		resp_cb=$(create_repo_cb "$REPO" "$DESCR" "$TOKEN_CB")
	else
		echo "Skipping creation on Codeberg as the repository already exists."
	fi

	local repo_rem_url_gh
	local repo_rem_url_gl
	local repo_rem_url_cb

	repo_rem_url_gh=$(repo_rem_url_get "$resp_gh" ".ssh_url")
	repo_rem_url_gl=$(repo_rem_url_get "$resp_gl" ".ssh_url_to_repo")
	repo_rem_url_cb=$(repo_rem_url_get "$resp_cb" ".ssh_url")

	repo_rem_add "$REPO_DIR" "github" "$repo_rem_url_gh" || exit 1
	repo_rem_add "$REPO_DIR" "gitlab" "$repo_rem_url_gl" || exit 1
	repo_rem_add "$REPO_DIR" "codeberg" "$repo_rem_url_cb" || exit 1

	repo_rem_push "$REPO_DIR" "github" "$BRANCH"
	repo_rem_push "$REPO_DIR" "gitlab" "$BRANCH"
	repo_rem_push "$REPO_DIR" "codeberg" "$BRANCH"
}

main "$@"
