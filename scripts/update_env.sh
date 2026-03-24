#!/bin/bash
# Update environment variables for a Dokploy compose service

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
COMPOSE_ID="$3"
ACTION="${4:-set}"  # set (default), get, append
ENV_VARS="${5:-}"   # KEY=VALUE pairs (space-separated) for set/append

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ] || [ -z "$COMPOSE_ID" ]; then
    echo "Usage: $0 <dokploy-url> <api-key> <compose-id> [action] [env-vars]"
    echo ""
    echo "Actions:"
    echo "  get     — Show current environment variables (default if no env-vars provided)"
    echo "  set     — Replace all environment variables with these (default if env-vars provided)"
    echo "  append  — Add/merge variables without removing existing ones"
    echo ""
    echo "Environment variables format: KEY=VALUE KEY2=VALUE2 ..."
    echo ""
    echo "Examples:"
    echo "  $0 https://main.spidmax.win API_KEY XQHAWkLmA6TJqoHQ9IWay get"
    echo "  $0 https://main.spidmax.win API_KEY XQHAWkLmA6TJqoHQ9IWay set 'DATABASE_URL=postgresql://db:5432/app NODE_ENV=production'"
    echo "  $0 https://main.spidmax.win API_KEY XQHAWkLmA6TJqoHQ9IWay append 'NEW_VAR=hello'"
    echo ""
    echo "Tip: Use compose IDs from list_services.sh"
    exit 1
fi

# Get current service info
echo "Fetching service info..."
SERVICE_INFO=$(curl -s "$DOKPLOY_URL/api/trpc/compose.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22composeId%22%3A%22$COMPOSE_ID%22%7D%7D%7D" \
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

# Determine action based on env_vars
if [ -z "$ENV_VARS" ] && [ "$ACTION" = "set" ]; then
    ACTION="get"
fi

case "$ACTION" in
    get)
        echo "📋 Environment variables for: $SERVICE_NAME ($COMPOSE_ID)"
        echo ""
        echo "$SERVICE_INFO" | python3 -c "
import sys, json

data = json.load(sys.stdin)
compose = data[0]['result']['data']['json']
env = compose.get('env', '') or compose.get('environment', '') or ''

if env:
    # Parse env string (could be KEY=VALUE\n or KEY=VALUE format)
    for line in env.strip().split('\n'):
        if line.strip():
            print(line.strip())
else:
    print('(no environment variables set)')
" 2>/dev/null
        ;;
    
    set|append)
        if [ "$ACTION" = "set" ]; then
            echo "📝 Setting environment variables for: $SERVICE_NAME ($COMPOSE_ID)"
        else
            echo "📝 Appending environment variables for: $SERVICE_NAME ($COMPOSE_ID)"
        fi

        # Build the env string
        if [ "$ACTION" = "append" ]; then
            # Get existing env vars
            EXISTING_ENV=$(echo "$SERVICE_INFO" | python3 -c "
import sys, json
data = json.load(sys.stdin)
compose = data[0]['result']['data']['json']
env = compose.get('env', '') or compose.get('environment', '') or ''
print(env)
" 2>/dev/null || echo "")
            
            # Parse existing into associative array
            declare -A ENV_MAP
            if [ -n "$EXISTING_ENV" ]; then
                while IFS= read -r line; do
                    if [[ "$line" == *"="* ]]; then
                        KEY="${line%%=*}"
                        VALUE="${line#*=}"
                        ENV_MAP["$KEY"]="$VALUE"
                    fi
                done <<< "$EXISTING_ENV"
            fi
            
            # Merge new values
            for VAR in $ENV_VARS; do
                if [[ "$VAR" == *"="* ]]; then
                    KEY="${VAR%%=*}"
                    VALUE="${VAR#*=}"
                    ENV_MAP["$KEY"]="$VALUE"
                fi
            done
            
            # Rebuild env string
            NEW_ENV=""
            for KEY in "${!ENV_MAP[@]}"; do
                NEW_ENV="${NEW_ENV}${KEY}=${ENV_MAP[$KEY]}\n"
            done
            NEW_ENV=$(echo -e "$NEW_ENV" | sed '/^$/d')
        else
            # Set mode: just use the new values
            NEW_ENV=""
            for VAR in $ENV_VARS; do
                if [[ "$VAR" == *"="* ]]; then
                    NEW_ENV="${NEW_ENV}${VAR}\n"
                fi
            done
            NEW_ENV=$(echo -e "$NEW_ENV" | sed '/^$/d')
        fi
        
        echo "  Variables:"
        echo "$NEW_ENV" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                KEY="${line%%=*}"
                VALUE="${line#*=}"
                # Mask sensitive values
                if [[ "$KEY" == *"PASSWORD"* ]] || [[ "$KEY" == *"SECRET"* ]] || [[ "$KEY" == *"TOKEN"* ]]; then
                    echo "    $KEY=***"
                else
                    echo "    $line"
                fi
            fi
        done
        
        # Update the service
        echo ""
        echo "Updating service..."
        
        UPDATE_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/trpc/compose.update?batch=1" \
            -H "x-api-key: $DOKPLOY_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"0\":{\"json\":{\"composeId\":\"$COMPOSE_ID\",\"env\":\"$(echo -e "$NEW_ENV" | tr '\n' '\\' | sed 's/\\$//')\"}}}")
        
        if echo "$UPDATE_RESPONSE" | grep -q '"error"'; then
            ERROR_MSG=$(echo "$UPDATE_RESPONSE" | python3 -c "
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
        
        echo "✅ Environment variables updated!"
        echo ""
        echo "⚠️  Changes will take effect on next deployment."
        echo "   Trigger a redeploy with:"
        echo "   restart_service.sh $DOKPLOY_URL $DOKPLOY_API_KEY compose $COMPOSE_ID"
        ;;
    
    *)
        echo "Error: Unknown action: $ACTION"
        echo "Valid actions: get, set, append"
        exit 1
        ;;
esac
