#!/bin/bash
# Configure Dokploy docker-compose deployment with GitHub webhook
# Domains are configured via Traefik labels in docker-compose.yml

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
GITHUB_REPO_URL="$3"
PROJECT_ID="$4"
SERVICE_NAME="${5:-web}"
COMPOSE_FILE="${6:-docker-compose.yml}"
ENVIRONMENT_ID="${7:-}"  # Optional: pre-resolved environment ID (from list_or_create_project.sh)

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ] || [ -z "$GITHUB_REPO_URL" ] || [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 <dokploy-url> <dokploy-api-key> <github-repo-url> <project-id> [service-name] [compose-file] [environment-id]"
    echo ""
    echo "Note: Configure domains via Traefik labels in docker-compose.yml"
    echo "      See references/traefik-labels.md for examples"
    echo ""
    echo "Tip: Use list_or_create_project.sh first to discover or create a project."
    echo ""
    echo "Examples:"
    echo "  $0 https://main.spidmax.win API_KEY https://github.com/user/repo PROJECT_ID"
    echo "  $0 https://main.spidmax.win API_KEY https://github.com/user/repo PROJECT_ID web docker-compose.yml ENV_ID"
    exit 1
fi

# Extract repo owner and name from URL
REPO_PATH=$(echo "$GITHUB_REPO_URL" | sed 's|https://github.com/||' | sed 's|\.git$||')
OWNER=$(echo "$REPO_PATH" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO_PATH" | cut -d'/' -f2)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Setting up Dokploy compose deployment for: $OWNER/$REPO_NAME"
echo ""

# Pre-deployment validation
echo "=== Pre-deployment Validation ==="
if [ -f "./$COMPOSE_FILE" ]; then
    bash "$SCRIPT_DIR/validate_deployment.sh" "./$COMPOSE_FILE"
else
    echo "⚠ Compose file not found locally, skipping validation"
fi
echo ""

# If no environment ID was passed, look it up from the project
if [ -z "$ENVIRONMENT_ID" ]; then
    echo "Fetching project details to find default environment..."
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
        echo "Run list_or_create_project.sh first to discover or create a project."
        exit 1
    fi
fi

echo "Using environment: $ENVIRONMENT_ID"

# Get GitHub provider ID (needed for both create and update)
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
    echo "Please configure a GitHub provider in Dokploy UI: $DOKPLOY_URL/dashboard/settings/git-providers"
    exit 1
fi

echo "Using GitHub provider: $GITHUB_ID"

# Check if compose service already exists for this repo
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
    echo "✓ Found existing compose service: $EXISTING_COMPOSE_ID"
    echo "Updating existing service instead of creating new one..."
    COMPOSE_ID="$EXISTING_COMPOSE_ID"

    # Update the existing compose service (with githubId for webhook)
    UPDATE_COMPOSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.update?batch=1" \
        -H "x-api-key: $DOKPLOY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"0\":{\"json\":{\"composeId\":\"$COMPOSE_ID\",\"githubId\":\"$GITHUB_ID\",\"repository\":\"$REPO_NAME\",\"owner\":\"$OWNER\",\"branch\":\"main\",\"composePath\":\"./$COMPOSE_FILE\",\"sourceType\":\"github\",\"autoDeploy\":true}}}")

    if echo "$UPDATE_COMPOSE" | grep -q '"error"'; then
        UPDATE_ERROR=$(echo "$UPDATE_COMPOSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0].get('error', {}).get('json', {}).get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
        echo "Error updating compose service: $UPDATE_ERROR"
        exit 1
    fi

    echo "✓ Compose service updated: $COMPOSE_ID"
else
    # Create Dokploy compose service via tRPC API
    echo "Creating new compose service..."
    RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.create?batch=1" \
        -H "x-api-key: $DOKPLOY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"0\":{\"json\":{\"name\":\"$REPO_NAME\",\"appName\":\"$REPO_NAME\",\"environmentId\":\"$ENVIRONMENT_ID\",\"sourceType\":\"github\",\"repository\":\"$REPO_NAME\",\"owner\":\"$OWNER\",\"branch\":\"main\",\"composePath\":\"./$COMPOSE_FILE\",\"composeType\":\"docker-compose\",\"autoDeploy\":true,\"composeFile\":\"\"}}}")

    # Check for errors
    if echo "$RESPONSE" | grep -q '"error"'; then
        ERROR=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0].get('error', {}).get('json', {}).get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
        echo "Error: $ERROR"
        echo "Full response: $RESPONSE"
        exit 1
    fi

    # Extract compose ID
    COMPOSE_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['result']['data']['json']['composeId'])" 2>/dev/null || echo "")

    if [ -z "$COMPOSE_ID" ]; then
        echo "Error: Could not extract compose ID"
        echo "Response: $RESPONSE"
        exit 1
    fi

    echo "✓ Compose service created: $COMPOSE_ID"

    # Configure GitHub repository for new service
    echo "Configuring GitHub repository..."

    UPDATE_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.update?batch=1" \
        -H "x-api-key: $DOKPLOY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"0\":{\"json\":{\"composeId\":\"$COMPOSE_ID\",\"githubId\":\"$GITHUB_ID\",\"repository\":\"$REPO_NAME\",\"owner\":\"$OWNER\",\"branch\":\"main\",\"sourceType\":\"github\"}}}")

    if echo "$UPDATE_RESPONSE" | grep -q '"error"'; then
        UPDATE_ERROR=$(echo "$UPDATE_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0].get('error', {}).get('json', {}).get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
        echo "Error: Repository configuration failed: $UPDATE_ERROR"
        exit 1
    fi

    echo "✓ GitHub repository configured"
fi

    echo "✓ GitHub repository configured"
fi

echo ""
if [ -n "$EXISTING_COMPOSE_ID" ]; then
    echo "✓ Deployment updated successfully!"
else
    echo "✓ Deployment configured successfully!"
fi
echo "  - Compose ID: $COMPOSE_ID"
echo "  - Repository: https://github.com/$REPO_PATH"
echo "  - Auto-deploy: enabled on push to main"
echo ""
echo "Note: Configure domains via Traefik labels in docker-compose.yml"
echo "      See references/traefik-labels.md for examples"

echo ""
echo "Triggering deployment..."

# Trigger deployment (deploy for new services, redeploy for updates)
if [ -n "$EXISTING_COMPOSE_ID" ]; then
    DEPLOY_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.deploy?batch=1" \
        -H "x-api-key: $DOKPLOY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"0\":{\"json\":{\"composeId\":\"$COMPOSE_ID\",\"title\":\"Updated deployment\"}}}")
else
    DEPLOY_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.deploy?batch=1" \
        -H "x-api-key: $DOKPLOY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"0\":{\"json\":{\"composeId\":\"$COMPOSE_ID\",\"title\":\"Initial deployment\"}}}")
fi

if echo "$DEPLOY_RESPONSE" | grep -q '"success":true'; then
    echo "✓ Deployment queued successfully"
    echo ""

    # Post-deployment health check (two-phase: build + Traefik propagation)
    echo "=== Post-deployment Health Check ==="
    echo "Phase 1: Waiting for Dokploy build/deploy (up to 10 min for large apps)..."

    # Phase 1: Wait for Dokploy to finish building (build times vary by app complexity)
    BUILD_WAIT_MAX=120  # max iterations (120 x 5s = 10 min)
    BUILD_DONE=false
    for i in $(seq 1 $BUILD_WAIT_MAX); do
        sleep 5
        STATUS_RESPONSE=$(curl -s "$DOKPLOY_URL/api/trpc/compose.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22composeId%22%3A%22$COMPOSE_ID%22%7D%7D%7D" \
            -H "x-api-key: $DOKPLOY_API_KEY")

        DEPLOY_STATUS=$(echo "$STATUS_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    compose = data[0]['result']['data']['json']
    print(compose.get('composeStatus', 'unknown'))
except:
    print('error')
" 2>/dev/null || echo "error")

        case "$DEPLOY_STATUS" in
            "done"|"running")
                ELAPSED=$((i*5))
                echo "  [${ELAPSED}s] Dokploy status: $DEPLOY_STATUS ✓"
                BUILD_DONE=true
                break
                ;;
            "error")
                echo "✗ Deployment failed!"
                echo ""
                echo "Check deployment logs in Dokploy UI:"
                echo "  $DOKPLOY_URL/dashboard/project/$PROJECT_ID/services/compose/$COMPOSE_ID"
                exit 1
                ;;
            "building")
                echo "  [$((i*5))s] Building..."
                ;;
            *)
                echo "  [$((i*5))s] Status: $DEPLOY_STATUS"
                ;;
        esac
    done

    if [ "$BUILD_DONE" = true ]; then
        echo ""
        echo "✓ Deployment completed successfully!"
        echo ""
        echo "Note: If you configured Traefik labels in docker-compose.yml,"
        echo "      your service should be accessible at the configured domain(s)."
    fi

    echo ""
    echo "Next steps:"
    echo "  1. View dashboard: $DOKPLOY_URL/dashboard/project/$PROJECT_ID/services/compose/$COMPOSE_ID"
    echo "  2. Configure domains via Traefik labels (see references/traefik-labels.md)"
    echo "  3. Future pushes to main will auto-deploy"
else
    DEPLOY_ERROR=$(echo "$DEPLOY_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0].get('error', {}).get('json', {}).get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
    echo "⚠ Deployment trigger failed: $DEPLOY_ERROR"
    echo ""
    echo "Manual steps required:"
    echo "  1. Go to: $DOKPLOY_URL/dashboard/project/$PROJECT_ID/services/compose/$COMPOSE_ID"
    echo "  2. Click 'Deploy' to start the deployment"
fi
