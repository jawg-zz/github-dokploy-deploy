#!/bin/bash
# Create a GitHub repository via API

set -e

REPO_NAME="$1"
GITHUB_TOKEN="$2"

if [ -z "$REPO_NAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Usage: $0 <repo-name> <github-token>"
    exit 1
fi

# Create repo via GitHub API
RESPONSE=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/user/repos \
    -d "{\"name\":\"$REPO_NAME\",\"private\":false}")

# Check for errors
if echo "$RESPONSE" | grep -q '"message"'; then
    ERROR=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    echo "Error: $ERROR"
    exit 1
fi

# Extract repo URL
REPO_URL=$(echo "$RESPONSE" | grep -o '"clone_url":"[^"]*"' | cut -d'"' -f4)

if [ -z "$REPO_URL" ]; then
    echo "Error: Could not extract repo URL"
    echo "$RESPONSE"
    exit 1
fi

echo "$REPO_URL"
