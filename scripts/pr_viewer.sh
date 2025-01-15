#!/bin/bash

BRANCH=$1

if [ "$1" == "" ]; then
	BRANCH=$(git branch --show-current)
fi

URL=$(gh pr view "$BRANCH" --json url --jq ".url")

if [[ "$URL" == *"http"* ]]; then
	open -u "$URL"
	echo "$URL"
	exit 1
fi

echo "$URL"
