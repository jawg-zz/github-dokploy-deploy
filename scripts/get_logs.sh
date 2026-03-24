#!/bin/bash
# Fetch deployment logs for a Dokploy service

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
SERVICE_TYPE="$3"   # compose, app
SERVICE_ID="$4"     # The service ID
LINES="${5:-50}"    # Number of log lines (default: 50)
FOLLOW="${6:-false}"  # Follow logs (true/false)

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ] || [ -z "$SERVICE_TYPE" ] || [ -z "$SERVICE_ID" ]; then
    echo "Usage: $0 <dokploy-url> <api-key> <service-type> <service-id> [lines] [follow]"
    echo ""
    echo "Service types:"
    echo "  compose  — Docker Compose service"
    echo "  app      — Standalone application"
    echo ""
    echo "Options:"
    echo "  lines  — Number of log lines (default: 50)"
    echo "  follow — true to stream logs continuously (default: false)"
    echo ""
    echo "Examples:"
    echo "  $0 https://main.spidmax.win API_KEY compose XQHAWkLmA6TJqoHQ9IWay"
    echo "  $0 https://main.spidmax.win API_KEY compose XQHAWkLmA6TJqoHQ9IWay 100"
    echo "  $0 https://main.spidmax.win API_KEY compose XQHAWkLmA6TJqoHQ9IWay 50 true"
    exit 1
fi

# Get service name
case "$SERVICE_TYPE" in
    compose)
        SERVICE_INFO=$(curl -s "$DOKPLOY_URL/api/trpc/compose.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22composeId%22%3A%22$SERVICE_ID%22%7D%7D%7D" \
            -H "x-api-key: $DOKPLOY_API_KEY")
        ;;
    app)
        echo "Application log fetching not yet supported via API"
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

echo "📋 Logs for: $SERVICE_NAME ($SERVICE_ID)"
echo "   Status: $CURRENT_STATUS"
echo ""

# Fetch compose service (deployments are embedded)
SERVICE_FULL=$(curl -s "$DOKPLOY_URL/api/trpc/compose.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22composeId%22%3A%22$SERVICE_ID%22%7D%7D%7D" \
    -H "x-api-key: $DOKPLOY_API_KEY")

# Get the latest deployment logs
echo "$SERVICE_FULL" | python3 -c "
import sys, json

data = json.load(sys.stdin)
compose = data[0].get('result', {}).get('data', {}).get('json', {})
deployments = compose.get('deployments', [])

if not deployments:
    print('No deployments found.')
    sys.exit(0)

# Sort by creation date (newest first)
deployments.sort(key=lambda d: d.get('createdAt', ''), reverse=True)

latest = deployments[0]
print(f'Latest deployment: {latest.get(\"deploymentId\", \"?\")}')
print(f'  Status: {latest.get(\"status\", \"unknown\")}')
print(f'  Created: {latest.get(\"createdAt\", \"unknown\")}')
print(f'  Title: {latest.get(\"title\", \"\")}')
print()

# Show log text
log_text = latest.get('logText', '') or latest.get('logs', '') or ''
if log_text:
    lines = ${LINES:-50}
    all_lines = log_text.split('\n')
    shown = all_lines[-lines:] if len(all_lines) > lines else all_lines
    print(f'--- Last {len(shown)} lines ---')
    for line in shown:
        print(line)
else:
    print('No log text available for this deployment.')

# Show recent deployments summary
if len(deployments) > 1:
    print()
    print(f'--- Recent deployments ({min(5, len(deployments))}) ---')
    for d in deployments[:5]:
        status_icon = {'done': '✅', 'error': '❌', 'running': '🚀', 'queued': '⏳'}.get(d.get('status', ''), '❓')
        print(f'  {status_icon} {d.get(\"createdAt\", \"?\")} | {d.get(\"status\", \"?\")} | {d.get(\"title\", \"\")}')
" 2>/dev/null

# Follow mode - poll for new deployments
if [ "$FOLLOW" = "true" ]; then
    echo ""
    echo "Following for new deployments (Ctrl+C to stop)..."
    
    LAST_DEPLOY_ID=$(echo "$SERVICE_FULL" | python3 -c "
import sys, json
data = json.load(sys.stdin)
compose = data[0].get('result', {}).get('data', {}).get('json', {})
deployments = compose.get('deployments', [])
if deployments:
    deployments.sort(key=lambda d: d.get('createdAt', ''), reverse=True)
    print(deployments[0].get('deploymentId', ''))
" 2>/dev/null || echo "")

    while true; do
        sleep 10
        NEW_FULL=$(curl -s "$DOKPLOY_URL/api/trpc/compose.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22composeId%22%3A%22$SERVICE_ID%22%7D%7D%7D" \
            -H "x-api-key: $DOKPLOY_API_KEY")
        
        NEW_ID=$(echo "$NEW_FULL" | python3 -c "
import sys, json
data = json.load(sys.stdin)
compose = data[0].get('result', {}).get('data', {}).get('json', {})
deployments = compose.get('deployments', [])
if deployments:
    deployments.sort(key=lambda d: d.get('createdAt', ''), reverse=True)
    print(deployments[0].get('deploymentId', ''))
" 2>/dev/null || echo "")

        if [ "$NEW_ID" != "$LAST_DEPLOY_ID" ] && [ -n "$NEW_ID" ]; then
            echo ""
            echo "🆕 New deployment detected: $NEW_ID"
            echo "$NEW_FULL" | python3 -c "
import sys, json
data = json.load(sys.stdin)
compose = data[0].get('result', {}).get('data', {}).get('json', {})
deployments = compose.get('deployments', [])
if deployments:
    deployments.sort(key=lambda d: d.get('createdAt', ''), reverse=True)
    latest = deployments[0]
    print(f'Status: {latest.get(\"status\", \"unknown\")}')
    print(f'Title: {latest.get(\"title\", \"\")}')
    log_text = latest.get('logText', '') or latest.get('logs', '') or ''
    if log_text:
        lines = log_text.split('\n')
        shown = lines[-20:]
        print('--- Last 20 lines ---')
        for line in shown:
            print(line)
" 2>/dev/null
            LAST_DEPLOY_ID="$NEW_ID"
        fi
    done
fi
