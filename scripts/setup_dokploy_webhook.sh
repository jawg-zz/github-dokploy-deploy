#!/bin/bash
# Configure Dokploy application with GitHub webhook

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
GITHUB_REPO_URL="$3"
PROJECT_ID="${4:-ixqvvqxb}"  # Default project ID

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ] || [ -z "$GITHUB_REPO_URL" ]; then
    echo "Usage: $0 <dokploy-url> <dokploy-api-key> <github-repo-url> [project-id]"
    exit 1
fi

# Extract repo owner and name from URL
# Handles both https://github.com/owner/repo and https://github.com/owner/repo.git
REPO_PATH=$(echo "$GITHUB_REPO_URL" | sed 's|https://github.com/||' | sed 's|\.git$||')
OWNER=$(echo "$REPO_PATH" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO_PATH" | cut -d'/' -f2)

echo "Setting up Dokploy deployment for: $OWNER/$REPO_NAME"

# Get project details to find the default environment ID
echo "Fetching project details..."
PROJECT_DATA=$(curl -s "$DOKPLOY_URL/api/trpc/project.all?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%7D%7D%7D" \
    -H "x-api-key: $DOKPLOY_API_KEY")

# Extract environment ID for the project
ENVIRONMENT_ID=$(echo "$PROJECT_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
projects = data[0]['result']['data']['json']
for p in projects:
    if p['projectId'] == '$PROJECT_ID':
        for env in p.get('environments', []):
            if env.get('isDefault', False):
                print(env['environmentId'])
                break
        break
" 2>/dev/null || echo "")

if [ -z "$ENVIRONMENT_ID" ]; then
    echo "Error: Could not find default environment for project $PROJECT_ID"
    exit 1
fi

echo "Using environment: $ENVIRONMENT_ID"

# Create Dokploy application via tRPC API
RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/application.create?batch=1" \
    -H "x-api-key: $DOKPLOY_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"0\":{\"json\":{\"name\":\"$REPO_NAME\",\"appName\":\"$REPO_NAME\",\"projectId\":\"$PROJECT_ID\",\"environmentId\":\"$ENVIRONMENT_ID\",\"sourceType\":\"github\",\"repository\":\"$REPO_PATH\",\"owner\":\"$OWNER\",\"branch\":\"main\",\"buildType\":\"dockerfile\",\"dockerfilePath\":\"./Dockerfile\",\"autoDeploy\":true}}}")

# Check for errors
if echo "$RESPONSE" | grep -q '"error"'; then
    ERROR=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    echo "Error: $ERROR"
    echo "Full response: $RESPONSE"
    exit 1
fi

# Extract application ID
APP_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['result']['data']['json']['applicationId'])" 2>/dev/null || echo "")

if [ -z "$APP_ID" ]; then
    echo "Warning: Could not extract application ID, but creation may have succeeded"
    echo "Response: $RESPONSE"
else
    echo "✓ Dokploy application created: $APP_ID"
fi

echo "✓ Auto-deploy enabled on push to main"
echo "✓ Repository: https://github.com/$REPO_PATH"
