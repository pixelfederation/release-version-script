#!/usr/bin/env bash

set -euo pipefail

DEBUG="${DEBUG:-0}"
if [[ "1" = "${DEBUG}" ]]; then
    set -x
fi

DRY_RUN="${DRY_RUN:-0}"
if [[ "1" = "${DRY_RUN}" ]]; then
    echo "Dry running.."
fi

if [[ "" = "$CURRENT_VERSION" ]]; then
  CURRENT_VERSION="$(git describe --abbrev=0 --tags | sed -E 's/v(.*)/\1/' || echo "0.0.0")"
fi

# Safe check - skips relese commit generation when already tagged commit
if [[ $(git name-rev --name-only --tags HEAD) = "v$CURRENT_VERSION" ]]; then
    echo "Already tagged or no new commits introduced. Skipping.."
    exit 0
fi

# Set GH env variables
GH_COMMITER_NAME="${GH_COMMITER_NAME:-Rastusik}"
GH_COMMITER_EMAIL="${GH_COMMITER_EMAIL:-konradobal@gmail.com}"
GH_REPOSITORY="${GH_REPOSITORY:-pixelfederation/swoole-bundle}"
GH_TOKEN="${GH_TOKEN:?"Provide \"GH_TOKEN\" variable with GitHub Personal Access Token"}"

# Configure git
git config user.name "${GH_COMMITER_NAME}"
git config user.email "${GH_COMMITER_EMAIL}"

GIT_COMMIT_MESSAGE_FIRST_LINE="$(git log -1 --pretty=%B | head -n 1)"
GIT_COMMIT_MESSAGE_RELEASE_COMMIT_MATCHED="$(echo "$GIT_COMMIT_MESSAGE_FIRST_LINE" | sed -E 's/^chore\(release\)\: v([a-zA-Z0-9\.\-]+) \:tada\:/\1/')"
# If sed matches, it means it is a release commit, otherwise strings should be equal
if [[ "$GIT_COMMIT_MESSAGE_FIRST_LINE" != "$GIT_COMMIT_MESSAGE_RELEASE_COMMIT_MATCHED" ]]; then
    NEW_VERSION="$GIT_COMMIT_MESSAGE_RELEASE_COMMIT_MATCHED"
    RELEASE_TAG="v$NEW_VERSION"

    echo "Matched release commit: $GIT_COMMIT_MESSAGE_FIRST_LINE"
    echo "Releasing version: $NEW_VERSION"

    GH_RELEASE_NOTES="$(conventional-changelog -p angular | awk 'NR > 3 { print }')"
    if [ "" = "$(echo -n "$GH_RELEASE_NOTES" | tr '\n' ' ')" ]; then
        GH_RELEASE_NOTES="### Miscellaneous

* Minor fixes"
    fi

    # Create and push tag
    git remote add authorized "https://${GH_COMMITER_NAME}:${GH_TOKEN}@github.com/${GH_REPOSITORY}.git"
    if [ "0" = "$DRY_RUN" ]; then
        git tag "$RELEASE_TAG"
        git push authorized "$RELEASE_TAG"
    else
        echo "Pushing $RELEASE_TAG.."
    fi
    git remote remove authorized

    # Make github release
    GH_RELEASE_DRAFT="${GH_RELEASE_DRAFT:-false}"
    GH_RELEASE_PRERELEASE="${GH_RELEASE_PRERELEASE:-false}"
    GH_RELEASE_DESCRIPTION="## Changelog

[Full changelog](https://github.com/${GH_REPOSITORY}/compare/v${CURRENT_VERSION}...v${NEW_VERSION})

${GH_RELEASE_NOTES}

## Installation

\`\`\`sh
composer require ${GH_REPOSITORY} ^${NEW_VERSION}
\`\`\`
"
    GH_RELEASE_DESCRIPTION_ESCAPED="${GH_RELEASE_DESCRIPTION//\"/\\\"}"
    GH_RELEASE_DESCRIPTION_ESCAPED="${GH_RELEASE_DESCRIPTION_ESCAPED//$'\n'/\\n}"
    GH_RELEASE_REQUEST_BODY="{
    \"tag_name\": \"${RELEASE_TAG}\",
    \"target_commitish\": \"master\",
    \"name\": \"${RELEASE_TAG}\",
    \"body\": \"${GH_RELEASE_DESCRIPTION_ESCAPED}\",
    \"draft\": ${GH_RELEASE_DRAFT},
    \"prerelease\": ${GH_RELEASE_PRERELEASE}
}"

    if [ "0" = "$DRY_RUN" ]; then
        curl -s -u "${GH_COMMITER_NAME}:${GH_TOKEN}" -X POST "https://api.github.com/repos/${GH_REPOSITORY}/releases" \
            -H "Content-Type: application/vnd.github.v3+json" \
            --data "${GH_RELEASE_REQUEST_BODY}" | jq
    else
        echo "Release description:"
        echo "⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽"
        echo "${GH_RELEASE_DESCRIPTION}"
        echo "⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺"
        echo "Release request body:"
        echo "⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽"
        echo "${GH_RELEASE_REQUEST_BODY}"
        echo "⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺"
    fi
    exit 0
fi

# Guess new version number
RECOMMENDED_BUMP=$(conventional-recommended-bump -p angular)

# Split version by dots
V[0]=""
V[1]=""
V[2]=""
IFS='.' read -r -a V <<< "$CURRENT_VERSION"

# Ignore postfix like "-dev"
V[2]=$(( V[2]+1 ))
V[2]=$(( V[2]-1 ))
OLD_VERSION_SEM="${V[0]}.${V[1]}.${V[2]}"

# When version is 0.x.x it is allowed to make braking changes on minor version
if [[ "0" = "${V[0]}" ]] && [[ "${RECOMMENDED_BUMP}" = "major" ]]; then
    RECOMMENDED_BUMP="minor";
fi;

# Increment semantic version numbers major.minor.patch
if [[ "${RECOMMENDED_BUMP}" = "major" ]]; then
    V[0]=$(( V[0]+1 ));
    V[1]=0;
    V[2]=0;
elif [[ "${RECOMMENDED_BUMP}" = "minor" ]]; then
    V[1]=$(( V[1]+1 ));
    V[2]=0;
elif [[ "${RECOMMENDED_BUMP}" = "patch" ]]; then
    V[2]=$(( V[2]+1 ));
else
    echo "Could not bump version"
    exit 1
fi

NEW_VERSION_SEM="${V[0]}.${V[1]}.${V[2]}"
NEW_VERSION=${CURRENT_VERSION//${OLD_VERSION_SEM}/${NEW_VERSION_SEM}}

echo "Preparing release of version: ${NEW_VERSION}"

RELEASE_TAG="v${NEW_VERSION}"
# Save release notes
git tag "${RELEASE_TAG}" > /dev/null 2>&1
GH_RELEASE_NOTES_HEADER="$(conventional-changelog -p angular -r 2 | awk 'NR > 4 { print }' | head -n 1)"
git tag -d "${RELEASE_TAG}" > /dev/null 2>&1
GH_RELEASE_NOTES="$(conventional-changelog -p angular | awk 'NR > 3 { print }')"
if [ "" = "$(echo -n "$GH_RELEASE_NOTES" | tr '\n' ' ')" ]; then
    GH_RELEASE_NOTES="### Miscellaneous

* Minor fixes"
fi

# Save changelog
CHANGELOG="$GH_RELEASE_NOTES_HEADER

[Full changelog](https://github.com/${GH_REPOSITORY}/compare/v${CURRENT_VERSION}...v${NEW_VERSION})

$GH_RELEASE_NOTES
"
NEXT_LINES="10"
LINES="$(wc -l <<< "$CHANGELOG")"
LINES=$((LINES+NEXT_LINES))

# Update CHANGELOG.md
if [ "0" = "$DRY_RUN" ]; then
    echo -e "$CHANGELOG\n$(cat CHANGELOG.md)" > CHANGELOG.md
else
    echo "Changelog file: (first $LINES lines)"
    echo "⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽"
    echo "$CHANGELOG"
    head -n "$NEXT_LINES" < CHANGELOG.md
    echo ""
    echo "⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺"
fi

# Create release commit
COMMIT_MESSAGE="chore(release): ${RELEASE_TAG} :tada:
$(conventional-changelog | awk 'NR > 1 { print }')
"

if [ "0" = "$DRY_RUN" ]; then
    git add CHANGELOG.md
    git commit -m "${COMMIT_MESSAGE}"
else
    echo "Commit message:"
    echo "⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽"
    echo "${COMMIT_MESSAGE}"
    echo "⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺"
fi

# Create pull requests
RELEASE_BRANCH="${RELEASE_BRANCH:-"master"}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-"develop"}"
BACKPORT_RELEASE_COMMIT_BRANCH_TEMPLATE="chore/release-$RELEASE_TAG"
PR_BASES="${PR_BASES:-"$RELEASE_BRANCH $DEFAULT_BRANCH"}"

git remote add authorized "https://${GH_COMMITER_NAME}:${GH_TOKEN}@github.com/${GH_REPOSITORY}.git"
for PR_BASE in $PR_BASES; do
    HEAD_BRANCH="$BACKPORT_RELEASE_COMMIT_BRANCH_TEMPLATE-$PR_BASE"
    GH_PR_BODY="$CHANGELOG

----

## Fast-forward merge instructions

1. Approve PR
2. Then run these commands in your local git repository:

\`\`\`sh
git fetch --all
git switch $PR_BASE
git pull origin $PR_BASE
git merge origin/$HEAD_BRANCH --ff-only
git push origin $PR_BASE
\`\`\`
"
    GH_PR_BODY_ESCAPED="${GH_PR_BODY//\"/\\\"}"
    GH_PR_BODY_ESCAPED="${GH_PR_BODY_ESCAPED//$'\n'/\\n}"

    GH_PULL_REQUEST_TITLE="chore(release): ${RELEASE_TAG} [$PR_BASE]"
    GH_PULL_REQUEST_BODY="{
    \"title\": \"${GH_PULL_REQUEST_TITLE}\",
    \"body\": \"${GH_PR_BODY_ESCAPED}\",
    \"head\": \"${HEAD_BRANCH}\",
    \"base\": \"${PR_BASE}\"
}"
    if [ "0" = "$DRY_RUN" ]; then
        git push authorized "HEAD:refs/heads/$HEAD_BRANCH"

        curl -s -u "${GH_COMMITER_NAME}:${GH_TOKEN}" -X POST "https://api.github.com/repos/${GH_REPOSITORY}/pulls" \
            -H "Content-Type: application/vnd.github.v3+json" \
            --data "${GH_PULL_REQUEST_BODY}" | jq
    else
        echo "Push release commit to head branch '$HEAD_BRANCH"
        echo "Create release pull request to '$PR_BASE' from head branch '$HEAD_BRANCH'"
        echo "Pull request title: $GH_PULL_REQUEST_TITLE"
        echo "Pull request body:"
        echo "⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽⎽"
        echo "${GH_PULL_REQUEST_BODY}"
        echo "⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺"
    fi
done
git remote remove authorized

echo "Please approve and fast-forward merge release pull requests!"
