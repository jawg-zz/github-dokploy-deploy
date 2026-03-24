#!/bin/bash
# Delete a compose service, application, or database from Dokploy

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
SERVICE_TYPE="$3"   # compose, app, postgres, mysql, mariadb, mongo, redis
SERVICE_ID="$4"     # The service ID to delete
DELETE_VOLUMES="${5:-true}"  # Delete associated volumes (default: true)

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ] || [ -z "$SERVICE_TYPE" ] || [ -z "$SERVICE_ID" ]; then
    echo "Usage: $0 <dokploy-url> <api-key> <service-type> <service-id> [delete-volumes]"
    echo ""
    echo "Service types:"
    echo "  compose    — Docker Compose service"
    echo "  app        — Standalone application (Dockerfile/Nixpacks)"
    echo "  postgres   — PostgreSQL database"
    echo "  mysql      — MySQL database"
    echo "  mariadb    — MariaDB database"
    echo "  mongo      — MongoDB database"
    echo "  redis      — Redis database"
    echo ""
    echo "delete-volumes: true (default) or false"
    echo ""
    echo "Tip: Use list_services.sh to find service IDs."
    echo ""
    echo "Examples:"
    echo "  $0 https://main.spidmax.win API_KEY compose XQHAWkLmA6TJqoHQ9IWay"
    echo "  $0 https://main.spidmax.win API_KEY compose XQHAWkLmA6TJqoHQ9IWay false"
    echo "  $0 https://main.spidmax.win API_KEY postgres abc123"
    exit 1
fi

# Get service name before deletion (for confirmation)
echo "Fetching service info..."

case "$SERVICE_TYPE" in
    compose)
        SERVICE_INFO=$(curl -s "$DOKPLOY_URL/api/trpc/compose.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22composeId%22%3A%22$SERVICE_ID%22%7D%7D%7D" \
            -H "x-api-key: $DOKPLOY_API_KEY")
        SERVICE_NAME=$(echo "$SERVICE_INFO" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    c = data[0]['result']['data']['json']
    print(c.get('name', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")
        ;;
    app)
        SERVICE_NAME="application-$SERVICE_ID"
        ;;
    *)
        SERVICE_NAME="database-$SERVICE_ID"
        ;;
esac

echo "⚠️  About to delete:"
echo "  Type: $SERVICE_TYPE"
echo "  Name: $SERVICE_NAME"
echo "  ID:   $SERVICE_ID"
echo "  Volumes: $DELETE_VOLUMES"
echo ""
echo "This cannot be undone!"
echo ""

# Determine the correct tRPC endpoint and payload
case "$SERVICE_TYPE" in
    compose)
        DELETE_ENDPOINT="compose.delete"
        PAYLOAD="{\"0\":{\"json\":{\"composeId\":\"$SERVICE_ID\",\"deleteVolumes\":$DELETE_VOLUMES}}}"
        ;;
    app)
        DELETE_ENDPOINT="application.delete"
        PAYLOAD="{\"0\":{\"json\":{\"applicationId\":\"$SERVICE_ID\",\"deleteVolumes\":$DELETE_VOLUMES}}}"
        ;;
    postgres)
        DELETE_ENDPOINT="postgres.delete"
        PAYLOAD="{\"0\":{\"json\":{\"postgresId\":\"$SERVICE_ID\",\"deleteVolumes\":$DELETE_VOLUMES}}}"
        ;;
    mysql)
        DELETE_ENDPOINT="mysql.delete"
        PAYLOAD="{\"0\":{\"json\":{\"mysqlId\":\"$SERVICE_ID\",\"deleteVolumes\":$DELETE_VOLUMES}}}"
        ;;
    mariadb)
        DELETE_ENDPOINT="mariadb.delete"
        PAYLOAD="{\"0\":{\"json\":{\"mariadbId\":\"$SERVICE_ID\",\"deleteVolumes\":$DELETE_VOLUMES}}}"
        ;;
    mongo)
        DELETE_ENDPOINT="mongo.delete"
        PAYLOAD="{\"0\":{\"json\":{\"mongoId\":\"$SERVICE_ID\",\"deleteVolumes\":$DELETE_VOLUMES}}}"
        ;;
    redis)
        DELETE_ENDPOINT="redis.delete"
        PAYLOAD="{\"0\":{\"json\":{\"redisId\":\"$SERVICE_ID\",\"deleteVolumes\":$DELETE_VOLUMES}}}"
        ;;
    *)
        echo "Error: Unknown service type: $SERVICE_TYPE"
        exit 1
        ;;
esac

echo "Deleting..."
DELETE_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/${DELETE_ENDPOINT}?batch=1" \
    -H "x-api-key: $DOKPLOY_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

# Check for errors
if echo "$DELETE_RESPONSE" | grep -q '"error"'; then
    ERROR_MSG=$(echo "$DELETE_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data[0].get('error', {}).get('json', {}).get('message', 'Unknown error'))
except:
    print('Unknown error')
" 2>/dev/null || echo "Unknown error")
    echo "Error: $ERROR_MSG"
    exit 1
fi

# Check for success
if echo "$DELETE_RESPONSE" | grep -q '"success":true'; then
    echo "✅ Successfully deleted $SERVICE_TYPE: $SERVICE_NAME ($SERVICE_ID)"
    if [ "$DELETE_VOLUMES" = true ]; then
        echo "   Associated volumes were also deleted."
    else
        echo "   Volumes were preserved."
    fi
else
    # Some delete endpoints return empty object on success
    if echo "$DELETE_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); exit(0 if d[0].get('result') is not None else 1)" 2>/dev/null; then
        echo "✅ Successfully deleted $SERVICE_TYPE: $SERVICE_NAME ($SERVICE_ID)"
        if [ "$DELETE_VOLUMES" = true ]; then
            echo "   Associated volumes were also deleted."
        fi
    else
        echo "⚠️  Unexpected response: $DELETE_RESPONSE"
    fi
fi
