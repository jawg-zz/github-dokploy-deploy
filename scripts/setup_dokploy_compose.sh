#!/bin/bash
# Configure Dokploy docker-compose deployment with GitHub webhook and subdomain

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
GITHUB_REPO_URL="$3"
PROJECT_ID="$4"
SUBDOMAIN="$5"
SERVICE_NAME="${6:-web}"  # Service name from docker-compose.yml, defaults to 'web'
COMPOSE_FILE="${7:-docker-compose.yml}"

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ] || [ -z "$GITHUB_REPO_URL" ] || [ -z "$PROJECT_ID" ] || [ -z "$SUBDOMAIN" ]; then
    echo "Usage: $0 <dokploy-url> <dokploy-api-key> <github-repo-url> <project-id> <subdomain> [service-name] [compose-file]"
    echo ""
    echo "Example:"
    echo "  $0 https://main.spidmax.win API_KEY https://github.com/user/repo IZQrpyqKizrOYJf-F5PYa myapp.example.com web docker-compose.yml"
    exit 1
fi

# Extract repo owner and name from URL
REPO_PATH=$(echo "$GITHUB_REPO_URL" | sed 's|https://github.com/||' | sed 's|\.git$||')
OWNER=$(echo "$REPO_PATH" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO_PATH" | cut -d'/' -f2)

echo "Setting up Dokploy compose deployment for: $OWNER/$REPO_NAME"

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
            # Check if repository matches
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
    
    # Update the existing compose service
    UPDATE_COMPOSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.update?batch=1" \
        -H "x-api-key: $DOKPLOY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"0\":{\"json\":{\"composeId\":\"$COMPOSE_ID\",\"repository\":\"$REPO_NAME\",\"owner\":\"$OWNER\",\"branch\":\"main\",\"composePath\":\"./$COMPOSE_FILE\",\"sourceType\":\"github\",\"autoDeploy\":true}}}")
    
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
    -d "{\"0\":{\"json\":{\"name\":\"$REPO_NAME\",\"appName\":\"$REPO_NAME\",\"environmentId\":\"$ENVIRONMENT_ID\",\"sourceType\":\"github\",\"repository\":\"$REPO_PATH\",\"owner\":\"$OWNER\",\"branch\":\"main\",\"composePath\":\"./$COMPOSE_FILE\",\"composeType\":\"docker-compose\",\"autoDeploy\":true,\"composeFile\":\"\"}}}")

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
fi

# Get GitHub provider ID
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

# Update compose with GitHub repository details (skip if we updated existing service)
if [ -z "$EXISTING_COMPOSE_ID" ]; then
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

# Create domain for the compose service (only if new service or domain doesn't exist)
echo "Checking for existing domain..."
EXISTING_DOMAINS=$(curl -s "$DOKPLOY_URL/api/trpc/compose.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22composeId%22%3A%22$COMPOSE_ID%22%7D%7D%7D" \
    -H "x-api-key: $DOKPLOY_API_KEY")

HAS_DOMAIN=$(echo "$EXISTING_DOMAINS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    compose = data[0]['result']['data']['json']
    domains = compose.get('domains', [])
    for domain in domains:
        if domain.get('host') == '$SUBDOMAIN':
            print('yes')
            sys.exit(0)
except:
    pass
" 2>/dev/null || echo "")

if [ -n "$HAS_DOMAIN" ]; then
    echo "✓ Domain already exists: https://$SUBDOMAIN"
else
    echo "Creating subdomain: $SUBDOMAIN..."

    # First, we need to get the service name from docker-compose.yml
    # For now, we'll ask the user or default to the first service
    # TODO: Parse docker-compose.yml to auto-detect service names
    SERVICE_NAME="${7:-web}"  # Default to 'web' if not provided

    DOMAIN_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/domain.create?batch=1" \
        -H "x-api-key: $DOKPLOY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"0\":{\"json\":{\"host\":\"$SUBDOMAIN\",\"https\":true,\"port\":5000,\"path\":\"/\",\"composeId\":\"$COMPOSE_ID\",\"domainType\":\"compose\",\"serviceName\":\"$SERVICE_NAME\",\"certificateType\":\"none\"}}}")

    # Check for domain creation errors
    if echo "$DOMAIN_RESPONSE" | grep -q '"error"'; then
        DOMAIN_ERROR=$(echo "$DOMAIN_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0].get('error', {}).get('json', {}).get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
        echo "Warning: Domain creation failed: $DOMAIN_ERROR"
        echo "You may need to configure the domain manually in Dokploy UI"
    else
        echo "✓ Domain created: https://$SUBDOMAIN"
    fi
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
echo "  - Domain: https://$SUBDOMAIN"
echo ""
echo "Triggering deployment..."

# Trigger initial deployment
DEPLOY_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.deploy?batch=1" \
    -H "x-api-key: $DOKPLOY_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"0\":{\"json\":{\"composeId\":\"$COMPOSE_ID\",\"title\":\"Initial deployment\"}}}")

if echo "$DEPLOY_RESPONSE" | grep -q '"success":true'; then
    echo "✓ Deployment queued successfully"
    echo ""
    echo "Next steps:"
    echo "  1. Monitor deployment in Dokploy UI: $DOKPLOY_URL/dashboard/project/$PROJECT_ID/services/compose/$COMPOSE_ID"
    echo "  2. Once deployed, access at: https://$SUBDOMAIN"
    if [ -z "$EXISTING_COMPOSE_ID" ]; then
        echo "  3. Future pushes to main will auto-deploy"
    else
        echo "  3. Changes pushed to main will auto-deploy"
    fi
else
    DEPLOY_ERROR=$(echo "$DEPLOY_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0].get('error', {}).get('json', {}).get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
    echo "⚠ Deployment trigger failed: $DEPLOY_ERROR"
    echo ""
    echo "Manual steps required:"
    echo "  1. Go to: $DOKPLOY_URL/dashboard/project/$PROJECT_ID/services/compose/$COMPOSE_ID"
    echo "  2. Click 'Deploy' to start the deployment"
    echo "  3. Configure GitHub webhook if needed"
fi
