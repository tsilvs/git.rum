#!/bin/bash

# git.repo

repo_check() {
	local i18n_repo_j="$1"
	local repo_dir="$2"
	if [ ! -d "$repo_dir/.git" ]; then
		echo "'$repo_dir': $(prop_get "$i18n_repo_j" '.not')"
		exit 1
	fi
}

repo_rem_add() {
	local i18n_rem_j="$1"
	local repo_dir="$2"
	local remote_name="$3"
	local url="$4"
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
