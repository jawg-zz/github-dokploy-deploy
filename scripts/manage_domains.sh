#!/bin/bash
# Manage domains for a service (add, remove, list)

set -e

DOKPLOY_URL="$1"
API_KEY="$2"
SERVICE_TYPE="$3"
SERVICE_ID="$4"
ACTION="$5"
DOMAIN="$6"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ -z "$DOKPLOY_URL" ]] || [[ -z "$API_KEY" ]] || [[ -z "$SERVICE_TYPE" ]] || [[ -z "$SERVICE_ID" ]] || [[ -z "$ACTION" ]]; then
    echo -e "${RED}Usage: $0 <dokploy-url> <api-key> <service-type> <service-id> <action> [domain]${NC}"
    echo ""
    echo "Service types: compose, application"
    echo "Actions: add, remove, list"
    echo ""
    echo "Examples:"
    echo "  # List domains"
    echo "  $0 https://dokploy.com abc123 compose svc-123 list"
    echo ""
    echo "  # Add domain"
    echo "  $0 https://dokploy.com abc123 compose svc-123 add example.com"
    echo ""
    echo "  # Remove domain"
    echo "  $0 https://dokploy.com abc123 compose svc-123 remove example.com"
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

# Validate action
case "$ACTION" in
    add|remove)
        if [[ -z "$DOMAIN" ]]; then
            echo -e "${RED}Domain required for $ACTION action${NC}"
            exit 1
        fi
        ;;
    list) ;;
    *)
        echo -e "${RED}Invalid action: $ACTION${NC}"
        echo "Valid actions: add, remove, list"
        exit 1
        ;;
esac

# Determine API endpoints
if [[ "$SERVICE_TYPE" == "compose" ]]; then
    LIST_ENDPOINT="$DOKPLOY_URL/api/domain.byComposeId"
    CREATE_ENDPOINT="$DOKPLOY_URL/api/domain.create"
    DELETE_ENDPOINT="$DOKPLOY_URL/api/domain.remove"
    ID_FIELD="composeId"
else
    LIST_ENDPOINT="$DOKPLOY_URL/api/domain.byApplicationId"
    CREATE_ENDPOINT="$DOKPLOY_URL/api/domain.create"
    DELETE_ENDPOINT="$DOKPLOY_URL/api/domain.remove"
    ID_FIELD="applicationId"
fi

detect_port_and_service() {
    local service_id="$1"
    
    # Get compose file from service
    if [[ "$SERVICE_TYPE" == "compose" ]]; then
        COMPOSE_DATA=$(curl -s -X GET "$DOKPLOY_URL/api/compose.one?composeId=$service_id" \
            -H "x-api-key: $API_KEY")
        
        COMPOSE_FILE=$(echo "$COMPOSE_DATA" | jq -r '.composeFile // empty')
        
        if [[ -n "$COMPOSE_FILE" ]]; then
            # Extract first service name
            SERVICE_NAME=$(echo "$COMPOSE_FILE" | grep -A 1 "^services:" | grep -v "^services:" | grep -v "^--$" | head -1 | sed 's/://g' | xargs)
            
            # Try to detect port from common patterns
            PORT=$(echo "$COMPOSE_FILE" | grep -oP 'ports:\s*-\s*"\K\d+' | head -1)
            
            # If no port found, try without quotes
            if [[ -z "$PORT" ]]; then
                PORT=$(echo "$COMPOSE_FILE" | grep -oP 'ports:\s*-\s*\K\d+' | head -1)
            fi
            
            # If still no port, check for expose
            if [[ -z "$PORT" ]]; then
                PORT=$(echo "$COMPOSE_FILE" | grep -oP 'expose:\s*-\s*\K\d+' | head -1)
            fi
            
            # Default ports based on common patterns in compose file
            if [[ -z "$PORT" ]]; then
                if echo "$COMPOSE_FILE" | grep -q "next"; then
                    PORT=3000
                elif echo "$COMPOSE_FILE" | grep -q "nest"; then
                    PORT=3000
                elif echo "$COMPOSE_FILE" | grep -q "express"; then
                    PORT=3000
                elif echo "$COMPOSE_FILE" | grep -q "vite\|vue\|react"; then
                    PORT=5173
                elif echo "$COMPOSE_FILE" | grep -q "django"; then
                    PORT=8000
                elif echo "$COMPOSE_FILE" | grep -q "fastapi"; then
                    PORT=8000
                elif echo "$COMPOSE_FILE" | grep -q "flask"; then
                    PORT=5000
                else
                    PORT=3000  # Default fallback
                fi
            fi
            
            echo "$PORT|$SERVICE_NAME"
            return
        fi
    fi
    
    # Fallback defaults
    echo "3000|app"
}

list_domains() {
    echo -e "${BLUE}Fetching domains for $SERVICE_TYPE: $SERVICE_ID${NC}"
    
    RESPONSE=$(curl -s -X GET "$LIST_ENDPOINT?${ID_FIELD}=$SERVICE_ID" \
        -H "x-api-key: $API_KEY")
    
    if echo "$RESPONSE" | jq -e 'type == "array"' > /dev/null 2>&1; then
        DOMAIN_COUNT=$(echo "$RESPONSE" | jq 'length')
        
        if [[ $DOMAIN_COUNT -eq 0 ]]; then
            echo -e "${YELLOW}No domains configured${NC}"
        else
            echo -e "${GREEN}Found $DOMAIN_COUNT domain(s):${NC}"
            echo ""
            echo "$RESPONSE" | jq -r '.[] | "  \(.host) (ID: \(.domainId), SSL: \(.https // false))"'
        fi
    else
        echo -e "${RED}Failed to fetch domains${NC}"
        echo "$RESPONSE" | jq '.'
        exit 1
    fi
}

add_domain() {
    echo -e "${BLUE}Adding domain: $DOMAIN${NC}"
    
    # Detect port and service name from compose file
    echo -e "${YELLOW}Detecting port and service name...${NC}"
    DETECTION=$(detect_port_and_service "$SERVICE_ID")
    PORT=$(echo "$DETECTION" | cut -d'|' -f1)
    SERVICE_NAME=$(echo "$DETECTION" | cut -d'|' -f2)
    
    echo -e "${GREEN}Detected:${NC} Port=$PORT, Service=$SERVICE_NAME"
    
    # Generate certificate name from domain
    CERT_NAME=$(echo "$DOMAIN" | tr '.' '-')
    
    RESPONSE=$(curl -s -X POST "$CREATE_ENDPOINT" \
        -H "x-api-key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"${ID_FIELD}\": \"$SERVICE_ID\",
            \"host\": \"$DOMAIN\",
            \"path\": \"/\",
            \"port\": $PORT,
            \"https\": true,
            \"certificateType\": \"letsencrypt\",
            \"uniqueConfigKey\": \"$CERT_NAME\",
            \"serviceName\": \"$SERVICE_NAME\"
        }")
    
    DOMAIN_ID=$(echo "$RESPONSE" | jq -r '.domainId // .id')
    
    if [[ -z "$DOMAIN_ID" ]] || [[ "$DOMAIN_ID" == "null" ]]; then
        echo -e "${RED}Failed to add domain${NC}"
        echo "$RESPONSE" | jq '.'
        exit 1
    fi
    
    echo -e "${GREEN}✓ Domain added successfully${NC}"
    echo "  Domain: $DOMAIN"
    echo "  Domain ID: $DOMAIN_ID"
    echo "  Port: $PORT"
    echo "  Service: $SERVICE_NAME"
    echo "  SSL: Enabled (Let's Encrypt)"
    echo ""
    echo "DNS Configuration:"
    echo "  Add an A record pointing $DOMAIN to your server IP"
    echo "  SSL certificate will be issued automatically once DNS propagates"
}

remove_domain() {
    echo -e "${BLUE}Removing domain: $DOMAIN${NC}"
    
    # First, get the domain ID
    DOMAINS=$(curl -s -X GET "$LIST_ENDPOINT?${ID_FIELD}=$SERVICE_ID" \
        -H "x-api-key: $API_KEY")
    
    DOMAIN_ID=$(echo "$DOMAINS" | jq -r ".[] | select(.host == \"$DOMAIN\") | .domainId")
    
    if [[ -z "$DOMAIN_ID" ]] || [[ "$DOMAIN_ID" == "null" ]]; then
        echo -e "${RED}Domain not found: $DOMAIN${NC}"
        exit 1
    fi
    
    RESPONSE=$(curl -s -X POST "$DELETE_ENDPOINT" \
        -H "x-api-key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"domainId\": \"$DOMAIN_ID\"
        }")
    
    if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
        echo -e "${RED}Failed to remove domain${NC}"
        echo "$RESPONSE" | jq '.'
        exit 1
    fi
    
    echo -e "${GREEN}✓ Domain removed successfully${NC}"
    echo "  Domain: $DOMAIN"
    echo "  Domain ID: $DOMAIN_ID"
}

# Execute action
case "$ACTION" in
    list)
        list_domains
        ;;
    add)
        add_domain
        ;;
    remove)
        remove_domain
        ;;
esac
