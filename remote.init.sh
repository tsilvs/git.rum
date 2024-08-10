#!/bin/bash

# Default values
DEFAULT_OWNER="$(id -un)"
DEFAULT_REPO="repo-$(uuidgen | awk -F \"-\" '{ print $5 }')"
DEFAULT_DESCR="Default description"
DEFAULT_BRANCH="main"

# Function to read user input with a default value
read_input() {
	local prompt="$1"
	local default="$2"
	read -p "$prompt [$default]: " input
	echo "${input:-$default}"
}

# Function to create a GitHub repository
create_repo_gh() {
	response_gh=$(curl -X POST \
		-H "Authorization: token $3" \
		-H "Accept: application/vnd.github.v3+json" \
		-d "{\"name\":\"$1\", \"description\":\"$2\", \"private\":false}" \
		"https://api.github.com/user/repos")
}

# Function to create a GitLab project
create_repo_gl() {
	response_gl=$(curl -X POST \
		-H "PRIVATE-TOKEN: $3" \
		-d "name=$1&description=$2" \
		"https://gitlab.com/api/v4/projects")
}

# Function to create a Codeberg repository
create_repo_cb() {
	response_cb=$(curl -X POST \
		-H "Authorization: token $3" \
		-H "Content-Type: application/json" \
		-d "{\"name\":\"$1\", \"description\":\"$2\", \"private\":false}" \
		"https://codeberg.org/api/v1/user/repos")
}

repo_rem_url_get() {
	RESP="$1"
	PROP="$2"
	REM_URL=$(echo "$RESP" | jq -r "$PROP")
	echp "$REM_URL"
}

repo_rem_add() {
	REM="$1"
	URL="$2"
	BR="$3"
	git remote add "$REM" "$URL"
}

repo_rem_push() {
	REM="$1"
	BR="$2"
	git push "$REM" "$BR"
}

declare -A repo_conf_labels
repo_conf_labels+=( ["OWNER"]="Owner" ["REPO"]="Repo Name" ["DESCR"]="Repo Description" ["MYTOKEN_GH"]="Token @ GitHub" ["MYTOKEN_GL"]="Token @ GitLab" ["MYTOKEN_CB"]="Token @ CodeBerg" )
declare -A repo_conf_values
repo_conf_values+=(  ) # Should contain final values, prompted or defaults

params_print() {
	declare -A param_labels
	param_labels=$1
	param_values=$2
	print_list=""
	l=0
	IFSB=$IFS
	IFS=$'\n'
	for key in "${!param_labels[@]}"
	do
		print_list+="${param_labels[$key]}\t$key\n"
		(( l < ${#repo_conf_labels[$key]} )) && l=${#repo_conf_labels[$key]}
	done
	IFS=$IFSB
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
}

prompt_to_go() {
	read -p "Do you want to proceed? (y/n): " confirm
	if [[ $confirm != "y" ]]; then
		echo "Operation canceled."
		exit 1
	fi
}

main() {
	read_all_inputs()

	echo "Please review before applying:"
	params_print repo_conf_labels repo_conf_values
	prompt_to_go

	resp_gh=$(create_repo_gh "$REPO" "$DESCR" "$TOKEN_GH")
	resp_gl=$(create_repo_gl "$REPO" "$DESCR" "$TOKEN_GL")
	resp_cb=$(create_repo_cb "$REPO" "$DESCR" "$TOKEN_CB")

	repo_rem_url_gh=$(repo_rem_url_get "$resp_gh" ".ssh_url")
	repo_rem_url_gl=$(repo_rem_url_get "$resp_gl" ".ssh_url_to_repo")
	repo_rem_url_cb=$(repo_rem_url_get "$resp_cb" ".ssh_url")
}
