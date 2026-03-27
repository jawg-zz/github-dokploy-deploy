#!/bin/bash
# Configure Dokploy docker-compose deployment with GitHub webhook

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
GITHUB_REPO_URL="$3"
PROJECT_ID="$4"
SERVICE_NAME="${5:-web}"
COMPOSE_FILE="${6:-docker-compose.yml}"
ENVIRONMENT_ID="${7:-}"

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ] || [ -z "$GITHUB_REPO_URL" ] || [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 <dokploy-url> <dokploy-api-key> <github-repo-url> <project-id> [service-name] [compose-file] [environment-id]"
    echo ""
    echo "Examples:"
    echo "  $0 https://main.spidmax.win API_KEY https://github.com/user/repo PROJECT_ID"
    echo "  $0 https://main.spidmax.win API_KEY https://github.com/user/repo PROJECT_ID web docker-compose.yml"
    exit 1
fi

REPO_PATH=$(echo "$GITHUB_REPO_URL" | sed 's|https://github.com/||' | sed 's|\.git$||')
OWNER=$(echo "$REPO_PATH" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO_PATH" | cut -d'/' -f2)

echo "Setting up Dokploy deployment for: $OWNER/$REPO_NAME"

if [ -z "$ENVIRONMENT_ID" ]; then
    echo "Fetching environment ID..."
    PROJECT_DATA=$(curl -s "$DOKPLOY_URL/api/trpc/project.all?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%7D%7D%7D" \
        -H "x-api-key: $DOKPLOY_API_KEY")

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
fi

echo "Environment: $ENVIRONMENT_ID"

echo "Fetching GitHub provider..."
GITHUB_DATA=$(curl -s "$DOKPLOY_URL/api/trpc/github.githubProviders?batch=1&input=%7B%220%22%3A%7B%7D%7D" \
    -H "x-api-key: $DOKPLOY_API_KEY")

GITHUB_ID=$(echo "$GITHUB_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
providers = data[0]['result']['data']['json']
if providers:
    print(providers[0]['githubId'])
" 2>/dev/null || echo "")

if [ -z "$GITHUB_ID" ]; then
    echo "Error: No GitHub provider found in Dokploy"
    exit 1
fi

echo "Checking for existing compose service..."
EXISTING_COMPOSE=$(curl -s "$DOKPLOY_URL/api/trpc/project.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22projectId%22%3A%22$PROJECT_ID%22%7D%7D%7D" \
    -H "x-api-key: $DOKPLOY_API_KEY")

EXISTING_COMPOSE_ID=$(echo "$EXISTING_COMPOSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    project = data[0]['result']['data']['json']
    for env in project.get('environments', []):
        for compose in env.get('compose', []):
            repo = compose.get('repository', '')
            if repo == '$REPO_NAME' or repo == '$REPO_PATH':
                print(compose['composeId'])
                sys.exit(0)
except:
    pass
" 2>/dev/null || echo "")

if [ -n "$EXISTING_COMPOSE_ID" ]; then
    echo "Found existing service: $EXISTING_COMPOSE_ID"
    COMPOSE_ID="$EXISTING_COMPOSE_ID"
else
    echo "Creating new compose service..."
    RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.create?batch=1" \
        -H "x-api-key: $DOKPLOY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"0\":{\"json\":{\"name\":\"$REPO_NAME\",\"appName\":\"$REPO_NAME\",\"environmentId\":\"$ENVIRONMENT_ID\",\"sourceType\":\"github\",\"repository\":\"$REPO_NAME\",\"owner\":\"$OWNER\",\"branch\":\"main\",\"composePath\":\"./$COMPOSE_FILE\",\"composeType\":\"docker-compose\",\"autoDeploy\":true,\"composeFile\":\"\"}}}")

    if echo "$RESPONSE" | grep -q '"error"'; then
        ERROR=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0].get('error', {}).get('json', {}).get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
        echo "Error: $ERROR"
        exit 1
    fi

    COMPOSE_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['result']['data']['json']['composeId'])" 2>/dev/null || echo "")

    if [ -z "$COMPOSE_ID" ]; then
        echo "Error: Could not extract compose ID"
        exit 1
    fi
fi

echo ""
echo "Deployment configured!"
echo "  - Compose ID: $COMPOSE_ID"
echo "  - Repository: https://github.com/$REPO_PATH"

echo ""
echo "Triggering deployment..."

DEPLOY_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.deploy?batch=1" \
    -H "x-api-key: $DOKPLOY_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"0\":{\"json\":{\"composeId\":\"$COMPOSE_ID\",\"title\":\"Deployment\"}}}")

if echo "$DEPLOY_RESPONSE" | grep -q '"success":true'; then
    echo "✓ Deployment started!"
    echo ""
    echo "Service URL: https://testsimple.spidmax.win"
else
    echo "Warning: Deployment trigger may have failed"
    echo "Check dashboard: $DOKPLOY_URL/dashboard/project/$PROJECT_ID/services/compose/$COMPOSE_ID"
fi