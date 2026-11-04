#!/bin/bash

BRANCH=$1

if [ "$1" == "" ]; then
  BRANCH=$(git branch --show-current)
fi

URL=$(gh pr view "$BRANCH" --json url --jq ".url")

if [[ "$URL" == *"http"* ]]; then
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL"
  else
    open "$URL"
  fi
  echo "$URL"
  exit 1
fi

echo "$URL"
