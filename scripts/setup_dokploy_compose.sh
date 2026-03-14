#!/bin/bash
# Configure Dokploy docker-compose deployment with GitHub webhook, subdomain, and optional database
# Features: smart updates, validation, health check, database provisioning

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
GITHUB_REPO_URL="$3"
PROJECT_ID="$4"
SUBDOMAIN="$5"
SERVICE_NAME="${6:-web}"
COMPOSE_FILE="${7:-docker-compose.yml}"
DATABASE_TYPE="${8:-none}"  # none, postgres, mysql, mongodb, mariadb, redis

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ] || [ -z "$GITHUB_REPO_URL" ] || [ -z "$PROJECT_ID" ] || [ -z "$SUBDOMAIN" ]; then
    echo "Usage: $0 <dokploy-url> <dokploy-api-key> <github-repo-url> <project-id> <subdomain> [service-name] [compose-file] [database-type]"
    echo ""
    echo "Database types: none, postgres, mysql, mongodb, mariadb, redis"
    echo ""
    echo "Example:"
    echo "  $0 https://main.spidmax.win API_KEY https://github.com/user/repo PROJECT_ID myapp.example.com web docker-compose.yml postgres"
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

# Create database if requested
DATABASE_ID=""
DATABASE_CONNECTION_STRING=""

if [ "$DATABASE_TYPE" != "none" ]; then
    echo "Creating $DATABASE_TYPE database..."

    DB_NAME="${REPO_NAME}-db"
    DB_USER="${REPO_NAME}_user"
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

    case "$DATABASE_TYPE" in
        postgres)
            DB_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/postgres.create?batch=1" \
                -H "x-api-key: $DOKPLOY_API_KEY" \
                -H "Content-Type: application/json" \
                -d "{\"0\":{\"json\":{\"name\":\"$DB_NAME\",\"appName\":\"$DB_NAME\",\"environmentId\":\"$ENVIRONMENT_ID\",\"databaseName\":\"$DB_NAME\",\"databaseUser\":\"$DB_USER\",\"databasePassword\":\"$DB_PASSWORD\"}}}")

            if echo "$DB_RESPONSE" | grep -q '"error"'; then
                echo "Warning: Database creation failed, continuing without database"
            else
                DATABASE_ID=$(echo "$DB_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['result']['data']['json']['postgresId'])" 2>/dev/null || echo "")
                DB_APP_NAME=$(echo "$DB_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['result']['data']['json']['appName'])" 2>/dev/null || echo "$DB_NAME")
                DATABASE_CONNECTION_STRING="postgresql://$DB_USER:$DB_PASSWORD@$DB_APP_NAME:5432/$DB_NAME"
                echo "✓ PostgreSQL database created: $DB_NAME (container: $DB_APP_NAME)"
            fi
            ;;
        mysql)
            DB_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/mysql.create?batch=1" \
                -H "x-api-key: $DOKPLOY_API_KEY" \
                -H "Content-Type: application/json" \
                -d "{\"0\":{\"json\":{\"name\":\"$DB_NAME\",\"appName\":\"$DB_NAME\",\"environmentId\":\"$ENVIRONMENT_ID\",\"databaseName\":\"$DB_NAME\",\"databaseUser\":\"$DB_USER\",\"databasePassword\":\"$DB_PASSWORD\"}}}")

            if echo "$DB_RESPONSE" | grep -q '"error"'; then
                echo "Warning: Database creation failed, continuing without database"
            else
                DATABASE_ID=$(echo "$DB_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['result']['data']['json']['mysqlId'])" 2>/dev/null || echo "")
                DATABASE_CONNECTION_STRING="mysql://$DB_USER:$DB_PASSWORD@$DB_NAME:3306/$DB_NAME"
                echo "✓ MySQL database created: $DB_NAME"
            fi
            ;;
        mongodb)
            DB_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/mongo.create?batch=1" \
                -H "x-api-key: $DOKPLOY_API_KEY" \
                -H "Content-Type: application/json" \
                -d "{\"0\":{\"json\":{\"name\":\"$DB_NAME\",\"appName\":\"$DB_NAME\",\"environmentId\":\"$ENVIRONMENT_ID\",\"databaseUser\":\"$DB_USER\",\"databasePassword\":\"$DB_PASSWORD\"}}}")

            if echo "$DB_RESPONSE" | grep -q '"error"'; then
                echo "Warning: Database creation failed, continuing without database"
            else
                DATABASE_ID=$(echo "$DB_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['result']['data']['json']['mongoId'])" 2>/dev/null || echo "")
                DATABASE_CONNECTION_STRING="mongodb://$DB_USER:$DB_PASSWORD@$DB_NAME:27017/$DB_NAME"
                echo "✓ MongoDB database created: $DB_NAME"
            fi
            ;;
        mariadb)
            DB_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/mariadb.create?batch=1" \
                -H "x-api-key: $DOKPLOY_API_KEY" \
                -H "Content-Type: application/json" \
                -d "{\"0\":{\"json\":{\"name\":\"$DB_NAME\",\"appName\":\"$DB_NAME\",\"environmentId\":\"$ENVIRONMENT_ID\",\"databaseName\":\"$DB_NAME\",\"databaseUser\":\"$DB_USER\",\"databasePassword\":\"$DB_PASSWORD\"}}}")

            if echo "$DB_RESPONSE" | grep -q '"error"'; then
                echo "Warning: Database creation failed, continuing without database"
            else
                DATABASE_ID=$(echo "$DB_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['result']['data']['json']['mariadbId'])" 2>/dev/null || echo "")
                DATABASE_CONNECTION_STRING="mariadb://$DB_USER:$DB_PASSWORD@$DB_NAME:3306/$DB_NAME"
                echo "✓ MariaDB database created: $DB_NAME"
            fi
            ;;
        redis)
            DB_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/redis.create?batch=1" \
                -H "x-api-key: $DOKPLOY_API_KEY" \
                -H "Content-Type: application/json" \
                -d "{\"0\":{\"json\":{\"name\":\"$DB_NAME\",\"appName\":\"$DB_NAME\",\"environmentId\":\"$ENVIRONMENT_ID\",\"databasePassword\":\"$DB_PASSWORD\"}}}")

            if echo "$DB_RESPONSE" | grep -q '"error"'; then
                echo "Warning: Database creation failed, continuing without database"
            else
                DATABASE_ID=$(echo "$DB_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['result']['data']['json']['redisId'])" 2>/dev/null || echo "")
                DATABASE_CONNECTION_STRING="redis://:$DB_PASSWORD@$DB_NAME:6379"
                echo "✓ Redis database created: $DB_NAME"
            fi
            ;;
    esac
fi

if [ -n "$EXISTING_COMPOSE_ID" ]; then
    echo "✓ Found existing compose service: $EXISTING_COMPOSE_ID"
    echo "Updating existing service instead of creating new one..."
    COMPOSE_ID="$EXISTING_COMPOSE_ID"

    # Build environment variables for update
    ENV_VARS=""
    if [ -n "$DATABASE_CONNECTION_STRING" ]; then
        ENV_VARS="DATABASE_URL=$DATABASE_CONNECTION_STRING"
    fi

    # Update the existing compose service (with githubId for webhook)
    UPDATE_COMPOSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.update?batch=1" \
        -H "x-api-key: $DOKPLOY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"0\":{\"json\":{\"composeId\":\"$COMPOSE_ID\",\"githubId\":\"$GITHUB_ID\",\"repository\":\"$REPO_NAME\",\"owner\":\"$OWNER\",\"branch\":\"main\",\"composePath\":\"./$COMPOSE_FILE\",\"sourceType\":\"github\",\"autoDeploy\":true$(if [ -n "$ENV_VARS" ]; then echo ",\"env\":\"$ENV_VARS\""; fi)}}}")

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

    # Configure GitHub repository and environment variables for new service
    echo "Configuring GitHub repository..."
    ENV_VARS=""
    if [ -n "$DATABASE_CONNECTION_STRING" ]; then
        ENV_VARS="DATABASE_URL=$DATABASE_CONNECTION_STRING"
    fi

    UPDATE_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.update?batch=1" \
        -H "x-api-key: $DOKPLOY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"0\":{\"json\":{\"composeId\":\"$COMPOSE_ID\",\"githubId\":\"$GITHUB_ID\",\"repository\":\"$REPO_NAME\",\"owner\":\"$OWNER\",\"branch\":\"main\",\"sourceType\":\"github\"$(if [ -n "$ENV_VARS" ]; then echo ",\"env\":\"$ENV_VARS\""; fi)}}}")

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
    # Auto-detect port from docker-compose.yml if possible
    if [ -f "./$COMPOSE_FILE" ]; then
        DETECTED_PORT=$(bash "$SCRIPT_DIR/detect_port.sh" "./$COMPOSE_FILE" "$SERVICE_NAME" 2>/dev/null || echo "5000")
    else
        DETECTED_PORT="5000"
    fi
    echo "Creating subdomain: $SUBDOMAIN (port: $DETECTED_PORT)..."

    DOMAIN_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/domain.create?batch=1" \
        -H "x-api-key: $DOKPLOY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"0\":{\"json\":{\"host\":\"$SUBDOMAIN\",\"https\":true,\"port\":$DETECTED_PORT,\"path\":\"/\",\"composeId\":\"$COMPOSE_ID\",\"domainType\":\"compose\",\"serviceName\":\"$SERVICE_NAME\",\"certificateType\":\"none\"}}}")

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

if [ -n "$DATABASE_ID" ]; then
    echo "  - Database: $DATABASE_TYPE ($DB_NAME)"
    echo "  - Database URL: $DATABASE_CONNECTION_STRING"
fi

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

    # Post-deployment health check
    echo "=== Post-deployment Health Check ==="
    echo "Waiting for deployment to complete (max 120 seconds)..."

    HEALTH_CHECK_PASSED=false
    for i in $(seq 1 24); do
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
            "done")
                echo "✓ Deployment completed!"
                HEALTH_CHECK_PASSED=true
                break
                ;;
            "error")
                echo "✗ Deployment failed!"
                echo ""
                echo "Check deployment logs in Dokploy UI:"
                echo "  $DOKPLOY_URL/dashboard/project/$PROJECT_ID/services/compose/$COMPOSE_ID"
                exit 1
                ;;
            "running")
                echo "  [$((i*5))s] Service is running"
                HEALTH_CHECK_PASSED=true
                break
                ;;
            "building")
                echo "  [$((i*5))s] Still building..."
                ;;
            *)
                echo "  [$((i*5))s] Status: $DEPLOY_STATUS"
                ;;
        esac
    done

    if [ "$HEALTH_CHECK_PASSED" = true ]; then
        echo ""
        echo "=== HTTP Health Check ==="
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$SUBDOMAIN" 2>/dev/null || echo "000")
        if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 400 ]; then
            echo "✓ Service is responding (HTTP $HTTP_STATUS): https://$SUBDOMAIN"
        else
            echo "⚠ Service not yet responding (HTTP $HTTP_STATUS)"
            echo "  It may need more time or there could be an issue."
            echo "  Check logs: $DOKPLOY_URL/dashboard/project/$PROJECT_ID/services/compose/$COMPOSE_ID"
        fi
    fi

    echo ""
    echo "Next steps:"
    echo "  1. View dashboard: $DOKPLOY_URL/dashboard/project/$PROJECT_ID/services/compose/$COMPOSE_ID"
    echo "  2. Access app: https://$SUBDOMAIN"
    echo "  3. Future pushes to main will auto-deploy"
    if [ -n "$DATABASE_CONNECTION_STRING" ]; then
        echo "  4. Database connection string set as DATABASE_URL environment variable"
    fi
else
    DEPLOY_ERROR=$(echo "$DEPLOY_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0].get('error', {}).get('json', {}).get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
    echo "⚠ Deployment trigger failed: $DEPLOY_ERROR"
    echo ""
    echo "Manual steps required:"
    echo "  1. Go to: $DOKPLOY_URL/dashboard/project/$PROJECT_ID/services/compose/$COMPOSE_ID"
    echo "  2. Click 'Deploy' to start the deployment"
fi
