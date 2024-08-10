#!/bin/bash

# Default values
DEFAULT_OWNER="$(id -un)"
DEFAULT_REPO="repo-$(uuidgen | awk -F \"-\" '{ print $5 }')"
DEFAULT_DESCR="Default description"
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
	local remote_name="$1"
	local url="$2"
	git remote add "$remote_name" "$url"
}

repo_rem_push() {
	local remote_name="$1"
	local branch="$2"
	git push "$remote_name" "$branch"
}

declare -A repo_conf_labels
repo_conf_labels+=( ["OWNER"]="Owner" ["REPO"]="Repo Name" ["DESCR"]="Repo Description" ["MYTOKEN_GH"]="Token @ GitHub" ["MYTOKEN_GL"]="Token @ GitLab" ["MYTOKEN_CB"]="Token @ CodeBerg" )

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
	OWNER=$(read_input "Enter owner" "$DEFAULT_OWNER")
	REPO=$(read_input "Enter repo name" "$DEFAULT_REPO")
	DESCR=$(read_input "Enter repo description" "$DEFAULT_DESCR")
	BRANCH=$(read_input "Enter branch name" "$DEFAULT_BRANCH")
	TOKEN_GH=$(read_input "Enter GitHub token" "")
	TOKEN_GL=$(read_input "Enter GitLab token" "")
	TOKEN_CB=$(read_input "Enter Codeberg token" "")
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
	read_all_inputs

	declare -A repo_conf_values
	repo_conf_values=( ["OWNER"]="$OWNER" ["REPO"]="$REPO" ["DESCR"]="$DESCR" ["MYTOKEN_GH"]="$TOKEN_GH" ["MYTOKEN_GL"]="$TOKEN_GL" ["MYTOKEN_CB"]="$TOKEN_CB" )

	echo "Please review before applying:"
	params_print repo_conf_labels repo_conf_values
	prompt_to_go

	local resp_gh
	local resp_gl
	local resp_cb

	resp_gh=$(create_repo_gh "$REPO" "$DESCR" "$TOKEN_GH")
	resp_gl=$(create_repo_gl "$REPO" "$DESCR" "$TOKEN_GL")
	resp_cb=$(create_repo_cb "$REPO" "$DESCR" "$TOKEN_CB")

	local repo_rem_url_gh
	local repo_rem_url_gl
	local repo_rem_url_cb

	repo_rem_url_gh=$(repo_rem_url_get "$resp_gh" ".ssh_url")
	repo_rem_url_gl=$(repo_rem_url_get "$resp_gl" ".ssh_url_to_repo")
	repo_rem_url_cb=$(repo_rem_url_get "$resp_cb" ".ssh_url")

	repo_rem_add "github" "$repo_rem_url_gh"
	repo_rem_add "gitlab" "$repo_rem_url_gl"
	repo_rem_add "codeberg" "$repo_rem_url_cb"

	repo_rem_push "github" "$BRANCH"
	repo_rem_push "gitlab" "$BRANCH"
	repo_rem_push "codeberg" "$BRANCH"
}

main
