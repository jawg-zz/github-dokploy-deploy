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

# Check for errors using proper JSON parsing
if echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); sys.exit(0 if 'message' not in data else 1)" 2>/dev/null; then
    # No error message field - check for API error structure
    :
else
    ERROR=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
    echo "Error: $ERROR"
    exit 1
fi

# Extract repo URL using proper JSON parsing
REPO_URL=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('clone_url', ''))" 2>/dev/null || echo "")

if [ -z "$REPO_URL" ]; then
    echo "Error: Could not extract repo URL"
    echo "$RESPONSE"
    exit 1
fi

echo "$REPO_URL"
