#!/bin/bash
# Track deployment status and show logs

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
COMPOSE_ID="$3"
FOLLOW="${4:-false}"  # Set to 'true' to follow logs

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ] || [ -z "$COMPOSE_ID" ]; then
    echo "Usage: $0 <dokploy-url> <dokploy-api-key> <compose-id> [follow]"
    echo ""
    echo "Example:"
    echo "  $0 https://main.spidmax.win API_KEY wQE1oJ9ihc8oOmBpb84C6"
    echo "  $0 https://main.spidmax.win API_KEY wQE1oJ9ihc8oOmBpb84C6 true"
    exit 1
fi

echo "Checking deployment status for: $COMPOSE_ID"
echo ""

check_status() {
    STATUS_RESPONSE=$(curl -s "$DOKPLOY_URL/api/trpc/compose.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22composeId%22%3A%22$COMPOSE_ID%22%7D%7D%7D" \
        -H "x-api-key: $DOKPLOY_API_KEY")
    
    STATUS=$(echo "$STATUS_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    compose = data[0]['result']['data']['json']
    print(compose.get('composeStatus', 'unknown'))
except:
    print('error')
" 2>/dev/null)
    
    echo "$STATUS"
}

# Initial status check
CURRENT_STATUS=$(check_status)

case "$CURRENT_STATUS" in
    "idle")
        echo "Status: ⏸️  Idle (not deployed yet)"
        ;;
    "running")
        echo "Status: 🚀 Running"
        ;;
    "done")
        echo "Status: ✅ Deployed successfully"
        ;;
    "error")
        echo "Status: ❌ Deployment failed"
        ;;
    "building")
        echo "Status: 🔨 Building..."
        ;;
    *)
        echo "Status: ❓ Unknown ($CURRENT_STATUS)"
        ;;
esac

# Follow mode - poll for status changes
if [ "$FOLLOW" = "true" ]; then
    echo ""
    echo "Following deployment status (Ctrl+C to stop)..."
    echo ""
    
    PREV_STATUS="$CURRENT_STATUS"
    
    while true; do
        sleep 5
        CURRENT_STATUS=$(check_status)
        
        if [ "$CURRENT_STATUS" != "$PREV_STATUS" ]; then
            echo "[$(date '+%H:%M:%S')] Status changed: $PREV_STATUS → $CURRENT_STATUS"
            
            case "$CURRENT_STATUS" in
                "done")
                    echo "✅ Deployment completed successfully!"
                    exit 0
                    ;;
                "error")
                    echo "❌ Deployment failed!"
                    echo ""
                    echo "Check logs in Dokploy UI:"
                    echo "  $DOKPLOY_URL/dashboard/project/*/services/compose/$COMPOSE_ID?tab=deployments"
                    exit 1
                    ;;
            esac
            
            PREV_STATUS="$CURRENT_STATUS"
        fi
    done
fi

echo ""
echo "View detailed logs in Dokploy UI:"
echo "  $DOKPLOY_URL/dashboard/project/*/services/compose/$COMPOSE_ID?tab=deployments"
