#!/bin/bash

# curl API requests with access tokens

# Remotes:
# + GitHub

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

response=$(curl -X POST \
	-H "Authorization: token $MYTOKEN_GH" \
	-H "Accept: application/vnd.github.v3+json" \
	"https://api.github.com/user/repos" \
  -d '{"name":"$REPO","description":"$DESCR","private":false}')

# + GitLab

response=$(curl --header "PRIVATE-TOKEN: $MYTOKEN_GL" \
	--data "name=$REPO&description=$DESCR" \
	"https://gitlab.com/api/v4/projects")

project_url=$(echo $response | jq -r '.http_url_to_repo')
git remote add $REM_GL $project_url
git push -u $REM_GL $BRANCH

# + Codeberg

response=$(curl -X POST \
	-H "Authorization: token $MYTOKEN_CB" \
	-H "Content-Type: application/json" \
	"https://codeberg.org/api/v1/user/repos" \
	-d '{"name":"$REPO", "description":"$DESCR", "private":false}')
