#!/bin/bash

print_list=""
l=0
IFSB=$IFS
IFS=$'\n'

declare -A repo_conf_labels
repo_conf_labels+=( ["OWNER"]="Owner" ["REPO"]="Repo Name" ["DESCR"]="Repo Description" ["MYTOKEN_GH"]="Token @ GitHub" ["MYTOKEN_GL"]="Token @ GitLab" ["MYTOKEN_CB"]="Token @ CodeBerg" )

for key in "${!repo_conf_labels[@]}"
do
	print_list+="${repo_conf_labels[$key]}\t$key\n"
	(( l < ${#repo_conf_labels[$key]} )) && l=${#repo_conf_labels[$key]}
done

IFS=$IFSB

tab_stop=$(tabs -d | awk -F "tabs " 'NR==1{ print $2 }')
tabs $(($l + 1))

echo -e "$print_list"

tabs $tab_stop
