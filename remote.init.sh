#!/bin/bash

# Default values
DEFAULT_OWNER="default_owner"
DEFAULT_REPO="default_repo"
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
create_github_repo() {
	response_gh=$(curl -X POST \
		-H "Authorization: token $MYTOKEN_GH" \
		-H "Accept: application/vnd.github.v3+json" \
		-d "{\"name\":\"$REPO\", \"description\":\"$DESCR\", \"private\":false}" \
		"https://api.github.com/user/repos")
}

# Function to create a GitLab project
create_gitlab_project() {
	response_gl=$(curl -X POST \
		-H "PRIVATE-TOKEN: $MYTOKEN_GL" \
		-d "name=$REPO&description=$DESCR" \
		"https://gitlab.com/api/v4/projects")
}

# Function to create a Codeberg repository
create_codeberg_repo() {
	response_cb=$(curl -X POST \
		-H "Authorization: token $MYTOKEN_CB" \
		-H "Content-Type: application/json" \
		-d "{\"name\":\"$REPO\", \"description\":\"$DESCR\", \"private\":false}" \
		"https://codeberg.org/api/v1/user/repos")
}

# GH: .ssh_url
# GL: .ssh_url_to_repo
# CB: .ssh_url

# Function to add remotes and push
add_remotes_and_push() {
	project_url_gh=$(echo $response_gh | jq -r '.html_url')
	git remote add $REM_GH $project_url_gh
	git push -u $REM_GH $BRANCH
}

read_input() {
	OWNER=$(read_input "Enter owner" "$DEFAULT_OWNER")
	REPO=$(read_input "Enter repo name" "$DEFAULT_REPO")
	DESCR=$(read_input "Enter repo description" "$DEFAULT_DESCR")
	BRANCH=$(read_input "Enter branch name" "$DEFAULT_BRANCH")

	echo "Please review before applying:"
	echo "  Owner:	$OWNER"
	echo "  Repo Name:	$REPO"
	echo "  Repo Description:	$DESCR"
	echo "  Token @ GitHub:	$TOKEN_GH"
	echo "  Token @ GitLab:	$TOKEN_GL"
	echo "  Token @ CodeBerg:	$TOKEN_CB"
}

read_input()

read -p "Do you want to proceed? (y/n): " confirm
if [[ $confirm != "y" ]]; then
	echo "Operation canceled."
	exit 1
fi

create_repo_gh "$REPO" "$DESCR" "$TOKEN_GH"
create_repo_gl "$REPO" "$DESCR" "$TOKEN_GL"
create_repo_cb "$REPO" "$DESCR" "$TOKEN_CB"
add_remotes_and_push 
