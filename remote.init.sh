#!/bin/bash

# Remotes:

TPLOWNER=""
TPLREPO=""
MYTOKEN_GH=""
MYTOKEN_GL=""
MYTOKEN_CB=""
REM_GH="gh"
REM_GL="gl"
REM_CB="cb"
OWNER=""
REPO=""
DESCR=""
BRANCH="main"

# + GitHub

response_gh=$(curl -X POST \
	-H "Authorization: token $MYTOKEN_GH" \
	-H "Accept: application/vnd.github.v3+json" \
	-d '{"name":"$REPO", "description":"$DESCR", "private":false}' \
	"https://api.github.com/user/repos")

# + GitLab

response_gl=$(curl -X POST \
	-H "PRIVATE-TOKEN: $MYTOKEN_GL" \
	-d "name=$REPO&description=$DESCR" \
	"https://gitlab.com/api/v4/projects")

# + Codeberg

response_cb=$(curl -X POST \
	-H "Authorization: token $MYTOKEN_CB" \
	-H "Content-Type: application/json" \
	-d '{"name":"$REPO", "description":"$DESCR", "private":false}' \
	"https://codeberg.org/api/v1/user/repos")

# Add remotes to a repo

project_url_gh=$(echo $response_gh | jq -r '.http_url_to_repo')
git remote add $REM_GL $project_url
git push -u $REM_GL $BRANCH
