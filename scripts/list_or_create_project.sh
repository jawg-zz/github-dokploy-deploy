#!/bin/bash
# List existing Dokploy projects or create a new one
# If no projects exist, automatically creates one
# If projects exist, lists them and lets user choose

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
NEW_PROJECT_NAME="$3"  # Optional: project name to create

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ]; then
    echo "Usage: $0 <dokploy-url> <api-key> [new-project-name]"
    exit 1
fi

# Fetch all projects
echo "Fetching Dokploy projects..."
PROJECT_DATA=$(curl -s "$DOKPLOY_URL/api/trpc/project.all?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%7D%7D%7D" \
    -H "x-api-key: $DOKPLOY_API_KEY")

# Parse projects
PROJECT_INFO=$(echo "$PROJECT_DATA" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    projects = data[0]['result']['data']['json']
    if not projects:
        print('NONE')
    else:
        for i, p in enumerate(projects):
            proj_id = p.get('projectId', 'unknown')
            name = p.get('name', proj_id)
            envs = p.get('environments', [])
            default_env = ''
            for e in envs:
                if e.get('isDefault', False):
                    default_env = e.get('environmentId', '')
                    break
            if not default_env and envs:
                default_env = envs[0].get('environmentId', '')
            # Output: index|projectId|name|defaultEnvironmentId
            print(f'{i}|{proj_id}|{name}|{default_env}')
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
" 2>/dev/null)

if [ "$PROJECT_INFO" = "NONE" ]; then
    echo "No existing projects found."

    # If a project name was provided, create one
    if [ -n "$NEW_PROJECT_NAME" ]; then
        echo "Creating new project: $NEW_PROJECT_NAME..."
        CREATE_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/project.create?batch=1" \
            -H "x-api-key: $DOKPLOY_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"0\":{\"json\":{\"name\":\"$NEW_PROJECT_NAME\"}}}")

        # Check for errors
        if echo "$CREATE_RESPONSE" | grep -q '"error"'; then
            ERROR=$(echo "$CREATE_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0].get('error', {}).get('json', {}).get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
            echo "Error creating project: $ERROR"
            exit 1
        fi

        # Extract project ID and default environment
        PROJECT_RESULT=$(echo "$CREATE_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
result = data[0]['result']['data']['json']
proj_id = result.get('projectId', '')
envs = result.get('environments', [])
env_id = ''
for e in envs:
    if e.get('isDefault', False):
        env_id = e.get('environmentId', '')
        break
if not env_id and envs:
    env_id = envs[0].get('environmentId', '')
print(f'{proj_id}|{env_id}')
" 2>/dev/null || echo "")

        if [ -z "$PROJECT_RESULT" ] || [ "$PROJECT_RESULT" = "|" ]; then
            echo "Error: Could not extract project details from creation response"
            echo "Response: $CREATE_RESPONSE"
            exit 1
        fi

        NEW_PROJECT_ID=$(echo "$PROJECT_RESULT" | cut -d'|' -f1)
        NEW_ENV_ID=$(echo "$PROJECT_RESULT" | cut -d'|' -f2)

        echo "PROJECT_CREATED"
        echo "Project ID: $NEW_PROJECT_ID"
        echo "Environment ID: $NEW_ENV_ID"
        echo "Project Name: $NEW_PROJECT_NAME"
    else
        echo "NO_PROJECTS"
        echo ""
        echo "No projects found in Dokploy."
        echo "Provide a project name to create one, or create one manually in the Dokploy UI."
        exit 0
    fi
elif echo "$PROJECT_INFO" | grep -q "^ERROR"; then
    echo "Error fetching projects:"
    echo "$PROJECT_INFO"
    exit 1
else
    # Projects exist — list them
    echo "EXISTING_PROJECTS"
    echo ""
    echo "Available projects:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$PROJECT_INFO" | while IFS='|' read -r idx proj_id name env_id; do
        echo "  [$((idx + 1))] $name (ID: $proj_id)"
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "PROJECT_LIST"
    # Output machine-readable format for programmatic use
    echo "$PROJECT_INFO"
fi
