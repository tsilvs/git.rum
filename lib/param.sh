#!/bin/bash

# lib.param

read_input() {
	local prompt="$1"
	local default="$2"
	local input
	read -rp "$prompt [$default]: " input
	echo "${input:-$default}"
}
