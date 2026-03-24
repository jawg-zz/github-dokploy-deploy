#!/bin/bash
# Configure watch paths for a service to trigger deployments only on specific file changes

set -e

DOKPLOY_URL="$1"
API_KEY="$2"
SERVICE_TYPE="$3"
SERVICE_ID="$4"
shift 4
WATCH_PATHS=("$@")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ -z "$DOKPLOY_URL" ]] || [[ -z "$API_KEY" ]] || [[ -z "$SERVICE_TYPE" ]] || [[ -z "$SERVICE_ID" ]]; then
    echo -e "${RED}Usage: $0 <dokploy-url> <api-key> <service-type> <service-id> <watch-path-1> [watch-path-2] ...${NC}"
    echo ""
    echo "Service types: compose, application"
    echo ""
    echo "Examples:"
    echo "  # Watch only src directory"
    echo "  $0 https://dokploy.com abc123 compose svc-123 'src/**'"
    echo ""
    echo "  # Watch multiple paths"
    echo "  $0 https://dokploy.com abc123 compose svc-123 'src/**' 'package.json' 'Dockerfile'"
    echo ""
    echo "  # Exclude paths with negation"
    echo "  $0 https://dokploy.com abc123 compose svc-123 'src/**' '!src/tests/**'"
    echo ""
    echo "Pattern matching features:"
    echo "  - Wildcards: *.js, **/*.ts"
    echo "  - Negation: !docs/**, !*.md"
    echo "  - Brace expansion: {src,lib}/**"
    echo "  - Character classes: [[:alpha:]]"
    exit 1
fi

# Validate service type
case "$SERVICE_TYPE" in
    compose|application) ;;
    *)
        echo -e "${RED}Invalid service type: $SERVICE_TYPE${NC}"
        echo "Valid types: compose, application"
        exit 1
        ;;
esac

if [[ ${#WATCH_PATHS[@]} -eq 0 ]]; then
    echo -e "${RED}No watch paths provided${NC}"
    exit 1
fi

echo -e "${BLUE}Configuring watch paths for $SERVICE_TYPE service: $SERVICE_ID${NC}"
echo ""
echo "Watch paths:"
for path in "${WATCH_PATHS[@]}"; do
    echo "  - $path"
done
echo ""

# Build JSON array of watch paths
PATHS_JSON=$(printf '%s\n' "${WATCH_PATHS[@]}" | jq -R . | jq -s .)

# Determine API endpoint
if [[ "$SERVICE_TYPE" == "compose" ]]; then
    API_ENDPOINT="$DOKPLOY_URL/api/compose.update"
    ID_FIELD="composeId"
else
    API_ENDPOINT="$DOKPLOY_URL/api/application.update"
    ID_FIELD="applicationId"
fi

# Update service with watch paths
RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
        \"$ID_FIELD\": \"$SERVICE_ID\",
        \"sourceType\": \"github\",
        \"autoDeploy\": true,
        \"customGitBuildPath\": \"/\",
        \"watchPaths\": $PATHS_JSON
    }")

# Check for errors
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    echo -e "${RED}Failed to configure watch paths${NC}"
    echo "$RESPONSE" | jq '.'
    exit 1
fi

echo -e "${GREEN}✓ Watch paths configured successfully${NC}"
echo ""
echo "Deployments will now trigger only when files matching these patterns change:"
for path in "${WATCH_PATHS[@]}"; do
    echo "  - $path"
done
echo ""
echo "Common patterns:"
echo "  src/**           - All files in src directory"
echo "  *.js             - All JavaScript files in root"
echo "  !docs/**         - Exclude docs directory"
echo "  {src,lib}/**     - Files in src OR lib"
echo "  package.json     - Specific file"
echo ""
echo "Next push will use these watch paths."
