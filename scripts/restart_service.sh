#!/bin/bash
# Restart (stop/start/redeploy) a Dokploy service

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
SERVICE_TYPE="$3"   # compose, app
SERVICE_ID="$4"     # The service ID
ACTION="${5:-redeploy}"  # redeploy (default), start, stop

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ] || [ -z "$SERVICE_TYPE" ] || [ -z "$SERVICE_ID" ]; then
    echo "Usage: $0 <dokploy-url> <api-key> <service-type> <service-id> [action]"
    echo ""
    echo "Service types:"
    echo "  compose  — Docker Compose service"
    echo "  app      — Standalone application"
    echo ""
    echo "Actions:"
    echo "  redeploy — Redeploy the service (default)"
    echo "  start    — Start the service"
    echo "  stop     — Stop the service"
    echo ""
    echo "Examples:"
    echo "  $0 https://main.spidmax.win API_KEY compose XQHAWkLmA6TJqoHQ9IWay"
    echo "  $0 https://main.spidmax.win API_KEY compose XQHAWkLmA6TJqoHQ9IWay stop"
    echo "  $0 https://main.spidmax.win API_KEY compose XQHAWkLmA6TJqoHQ9IWay start"
    exit 1
fi

# Get service name
echo "Fetching service info..."
case "$SERVICE_TYPE" in
    compose)
        SERVICE_INFO=$(curl -s "$DOKPLOY_URL/api/trpc/compose.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22composeId%22%3A%22$SERVICE_ID%22%7D%7D%7D" \
            -H "x-api-key: $DOKPLOY_API_KEY")
        ;;
    app)
        echo "Application restart not yet supported via API"
        exit 1
        ;;
    *)
        echo "Error: Unsupported service type: $SERVICE_TYPE"
        exit 1
        ;;
esac

SERVICE_NAME=$(echo "$SERVICE_INFO" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    c = data[0]['result']['data']['json']
    print(c.get('name', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

CURRENT_STATUS=$(echo "$SERVICE_INFO" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    c = data[0]['result']['data']['json']
    print(c.get('composeStatus', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

case "$ACTION" in
    redeploy)
        echo "🔄 Redeploying: $SERVICE_NAME ($SERVICE_ID)"
        echo "   Current status: $CURRENT_STATUS"
        
        DEPLOY_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.deploy?batch=1" \
            -H "x-api-key: $DOKPLOY_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"0\":{\"json\":{\"composeId\":\"$SERVICE_ID\",\"title\":\"Manual redeploy\"}}}")
        ;;
    start)
        echo "▶️  Starting: $SERVICE_NAME ($SERVICE_ID)"
        
        DEPLOY_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.start?batch=1" \
            -H "x-api-key: $DOKPLOY_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"0\":{\"json\":{\"composeId\":\"$SERVICE_ID\"}}}")
        ;;
    stop)
        echo "⏹️  Stopping: $SERVICE_NAME ($SERVICE_ID)"
        
        DEPLOY_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.stop?batch=1" \
            -H "x-api-key: $DOKPLOY_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"0\":{\"json\":{\"composeId\":\"$SERVICE_ID\"}}}")
        ;;
    *)
        echo "Error: Unknown action: $ACTION"
        echo "Valid actions: redeploy, start, stop"
        exit 1
        ;;
esac

# Check for errors
if echo "$DEPLOY_RESPONSE" | grep -q '"error"'; then
    ERROR_MSG=$(echo "$DEPLOY_RESPONSE" | python3 -c "
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
if echo "$DEPLOY_RESPONSE" | grep -q '"success":true'; then
    case "$ACTION" in
        redeploy)
            echo "✅ Redeployment queued for: $SERVICE_NAME"
            echo ""
            echo "Monitor progress:"
            echo "  $DOKPLOY_URL/dashboard/project/*/services/compose/$SERVICE_ID"
            echo ""
            echo "Tip: Use check_deployment_status.sh to monitor the deployment"
            ;;
        start)
            echo "✅ Service started: $SERVICE_NAME"
            ;;
        stop)
            echo "✅ Service stopped: $SERVICE_NAME"
            ;;
    esac
else
    # Some endpoints return empty object on success
    if echo "$DEPLOY_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); exit(0 if d[0].get('result') is not None else 1)" 2>/dev/null; then
        echo "✅ $ACTION completed for: $SERVICE_NAME ($SERVICE_ID)"
    else
        echo "⚠️  Unexpected response: $DEPLOY_RESPONSE"
    fi
fi
