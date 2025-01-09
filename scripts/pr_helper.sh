#!/bin/bash

LAST_COMMIT=$(git log --pretty=format:"%s" -n 1)
BRANCH=$(git branch --show-current)

PS3="Select the PR kind (1-2): "
PR_KIND=("regular" "draft")

select KIND in "${PR_KIND[@]}" 
do
    case $KIND in
        "regular")
            DRAFT=""
            break
            ;;
        "draft")
            DRAFT="-d"
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

echo ""
PS3="Select a PR type (1-8): "
TYPES=("feat" "fix" "test" "chore" "ci" "docs" "refactor" "style")

select TYPE in "${TYPES[@]}"
do
    case $TYPE in
        "feat")
            break
            ;;
        "fix")
            break
            ;;
        "test")
            break
            ;;
        "chore")
            break
            ;;
        "ci")
            break
            ;;
        "docs")
            break
            ;;
        "refactor")
            break
            ;;
        "style")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

echo ""
echo "Using '$TYPE' as PR type.."
echo "Using latest commit message for the PR title..."

# Latest commit has to include ":" character!
# replace entire commit message until first ":"
TITLE=$(echo $LAST_COMMIT | sed "s/^.*:/$TYPES($BRANCH):/")

echo ""
echo "Provide a PR description - Hint: \"<esc>:wq\" to exit Vim :D"
echo ""
read -p "Press ENTER to open Vim..."

vim -c 'startinsert' /tmp/input.$$
BODY=$(cat /tmp/input.$$)
rm /tmp/input.$$

# send it
gh pr create $DRAFT --title "$TITLE" --body "$BODY"
