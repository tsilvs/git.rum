#!/bin/bash

. ./lib/var.sh

. ./lib/net.sh

main() {
	lang="en" # should be a parameter & taken from the system by default
	
	tokens='{
		"gh": "your_github_token",
		"gl": "your_gitlab_token",
		"cb": "your_codeberg_token"
	}' # should be a parameter & taken from the system by default

	repo='the_user/the_repo'

	remotes='[
		{
			"prov": "gh",
			"url": "https://api.github.com/repos/",
			"headers": ["Authorization: token {{TOKEN}}", "Accept: application/vnd.github.v3+json"]
		},
		{
			"prov": "gl",
			"url": "https://gitlab.com/api/v4/projects/",
			"headers": ["PRIVATE-TOKEN: {{TOKEN}}"]
		},
		{
			"prov": "cb",
			"url": "https://codeberg.org/api/v1/repos/",
			"headers": ["Authorization: token {{TOKEN}}", "Content-Type: application/json"]
		}
	]'

	i18n='
	{
		"en": {
			"st": {
				"200": {
					"msg": "Repository exists"
				},
				"404": {
					"msg": "Repository does not exist"
				},
				"401": {
					"msg": "Authentication failed"
				},
				"403": {
					"msg": "Insufficient permissions"
				},
				"other": {
					"msg": "Error checking repository"
				}
			}
		}
	}
	'

	local handled_codes=("200" "404" "401" "403") # should be extracted by jq i18n

	for remote in $(echo "$remotes" | jq -c '.[]'); do
		prov=$(prop_get "$remote" '.prov')
		url=$(prop_get "$remote" '.url')
		token=$(prop_get "$tokens" ".$prov")
		headers=()
		
		for header in $(prop_get "$remote" '.headers[]'); do
			header=$(replace "$header" "{{TOKEN}}" "$token")
			headers+=("-H" "$header")
		done

		local resp=$(call_curl "$url" "${headers[@]}" "$repo")
		local status_code=$(http_code_get $resp) 
		echo "$res_path: $(prop_get "$i18n" ".$lang.st.$status_code.msg")"
	done
}

main
