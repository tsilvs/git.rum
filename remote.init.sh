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

response=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $MYTOKEN_GH" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$TPLOWNER/$TPLREPO/generate" \
  -d '{"owner":"$OWNER","name":"$REPO","description":"$DESCR","include_all_branches":false,"private":false}')

# + GitLab

response=$(curl --header "PRIVATE-TOKEN: $MYTOKEN_GL" \
     --data "name=$REPO" \
     "https://gitlab.com/api/v4/projects")

project_url=$(echo $response | jq -r '.http_url_to_repo')
git remote add $REM_GL $project_url
git push -u $REM_GL $BRANCH

# + Codeberg

