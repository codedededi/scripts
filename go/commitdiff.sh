#!/bin/bash

function cyclo {
    file=$1
    commit=$2
    output=$3

    if [ -z "$commit" ]; then
        gocyclo "$file" | awk '{printf("%s.%s %d\n", $2, $3, $1)}' | sort >"$output"
    else
        tmp_file="${workhome}/${file##*/}@${commit}.tmp"
        git show "${commit}:${file}" >"$tmp_file"
        gocyclo "$tmp_file" | awk '{printf("%s.%s %d\n", $2, $3, $1)}' | sort >"$output"
        rm "$tmp_file"
    fi
}

repository=$(pwd)
workhome=$(dirname "$0")
request_id=$(date '+%s')

if [ -f "${repository}/.git" ]; then
    echo "${repository} is not a git repository"
    exit 1
fi

cd "${repository}" || exit

commit1=$1
commit2=$2

diff_file="${workhome}/${request_id}.diff"
if [ -z "$commit2" ]; then
    if [ "$(git status --porcelain | wc -l)" -eq 0 ]; then
        echo "nonthing change, working tree clean"
        exit 0
    fi

    if [ -z "$commit1" ]; then
        commit1=$(git rev-parse HEAD)
    fi

    git status --porcelain | grep ".go$" >"${diff_file}"
else
    git diff --name-status "$commit1" "$commit2" | grep ".go$" >"${diff_file}"
fi

while read -r line; do
    line=${line/	/ }
    #TODO 区分不同变更类型的处理方式
    status="${line%% *}"
    target="${line##* }"
    file="${target##*/}"

    output1="${workhome}/${file}@${commit1}.output"
    output2="${workhome}/${file}@${commit2}.output"

    cyclo "$target" "$commit1" "$output1"
    cyclo "$target" "$commit2" "$output2"

    join -a 1 -a 2 -o '0, 1.2, 2.2' -e'0' "$output2" "$output1" | awk '$2!=$3 {print $1,$2-$3,$2}'

    rm "$output1" "$output2"

done <"$diff_file"

rm "$diff_file"
