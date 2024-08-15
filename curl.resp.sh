#!/bin/bash

store_curl_response() {
	local url=$1
	local response
	local http_code
	local headers
	local body

	response=$(curl -s -w "\n%{http_code}" "$url")

	http_code=$(echo "$response" | tail -n1)
	headers=$(echo "$response" | sed -e '/^\r$/q')
	body=$(echo "$response" | sed -e '1,/^\r$/d' | head -n -1)

	RESPONSE_CODE=$http_code
	RESPONSE_HEADERS=$headers
	RESPONSE_BODY=$body
}

#store_curl_response "https://api.github.com/repos/octocat/Hello-World"
#echo "HTTP Status Code: $RESPONSE_CODE"
#echo "Headers:"
#echo "$RESPONSE_HEADERS"
#echo "Body:"
#echo "$RESPONSE_BODY"

