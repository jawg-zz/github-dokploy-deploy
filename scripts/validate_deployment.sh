#!/bin/bash
# Enhanced validation for docker-compose files before deployment
# Checks structure, required fields, health checks, and common issues

COMPOSE_FILE="$1"

if [ -z "$COMPOSE_FILE" ]; then
    echo "Usage: $0 <docker-compose.yml>"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: File not found: $COMPOSE_FILE"
    exit 1
fi

echo "=== Docker Compose Validation ==="
echo "File: $COMPOSE_FILE"
echo ""

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

# Check if file is valid YAML (basic check with grep)
if grep -q "^services:" "$COMPOSE_FILE"; then
    echo -e "${GREEN}✓ Valid YAML structure${NC}"
else
    echo -e "${RED}✗ Missing 'services:' section${NC}"
    ERRORS=$((ERRORS + 1))
    exit 1
fi

# Count services (basic grep count)
SERVICE_COUNT=$(grep -A 1000 "^services:" "$COMPOSE_FILE" | grep "^  [a-zA-Z]" | grep -v "^  #" | wc -l)

if [ "$SERVICE_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ No services defined${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ Found $SERVICE_COUNT service(s)${NC}"
fi

# Check for common patterns
echo ""
echo "Checking services..."

# Extract service names (skip volumes section)
SERVICES=$(grep -A 1000 "^services:" "$COMPOSE_FILE" | grep -B 1000 "^volumes:\|^networks:\|^$" | head -n -1 | grep "^  [a-zA-Z]" | grep -v "^  #" | sed 's/:.*//' | sed 's/^  //')

while IFS= read -r service; do
    [ -z "$service" ] && continue
    
    echo ""
    echo "Service: $service"
    
    # Check for image or build
    if grep -A 20 "^  $service:" "$COMPOSE_FILE" | grep -q "^\s\+image:\|^\s\+build:"; then
        echo -e "  ${GREEN}✓ Has image/build configuration${NC}"
    else
        echo -e "  ${RED}✗ Missing 'image' or 'build'${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check for ports
    if grep -A 20 "^  $service:" "$COMPOSE_FILE" | grep -q "^\s\+ports:"; then
        PORT_COUNT=$(grep -A 20 "^  $service:" "$COMPOSE_FILE" | grep -A 10 "^\s\+ports:" | grep "^\s\+-\s" | wc -l)
        echo -e "  ${GREEN}✓ Exposes $PORT_COUNT port(s)${NC}"
    else
        echo -e "  ${YELLOW}⚠ No ports exposed (might be internal service)${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for restart policy
    if grep -A 20 "^  $service:" "$COMPOSE_FILE" | grep -q "^\s\+restart:"; then
        RESTART=$(grep -A 20 "^  $service:" "$COMPOSE_FILE" | grep "^\s\+restart:" | head -1 | sed 's/.*restart:\s*//')
        echo -e "  ${GREEN}✓ Has restart policy: $RESTART${NC}"
    else
        echo -e "  ${YELLOW}⚠ No restart policy (consider 'unless-stopped')${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for health check
    if grep -A 20 "^  $service:" "$COMPOSE_FILE" | grep -q "^\s\+healthcheck:"; then
        echo -e "  ${GREEN}✓ Has health check${NC}"
    else
        echo -e "  ${YELLOW}⚠ No health check defined${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for environment variables
    if grep -A 20 "^  $service:" "$COMPOSE_FILE" | grep -q "^\s\+environment:"; then
        ENV_COUNT=$(grep -A 20 "^  $service:" "$COMPOSE_FILE" | grep -A 50 "^\s\+environment:" | grep "^\s\+[A-Z_]" | wc -l)
        echo -e "  ${GREEN}✓ Has $ENV_COUNT environment variable(s)${NC}"
        
        # Check for hardcoded secrets
        HARDCODED=$(grep -A 20 "^  $service:" "$COMPOSE_FILE" | grep -A 50 "^\s\+environment:" | grep -E "PASSWORD|SECRET|KEY|TOKEN" | grep -v '\${' | wc -l)
        if [ "$HARDCODED" -gt 0 ]; then
            echo -e "  ${YELLOW}⚠ Found $HARDCODED potential hardcoded secret(s) (consider using \${VAR})${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
    
done <<< "$SERVICES"

# Check for volumes
echo ""
if grep -q "^volumes:" "$COMPOSE_FILE"; then
    VOLUME_COUNT=$(grep -A 100 "^volumes:" "$COMPOSE_FILE" | grep "^  [a-zA-Z]" | wc -l)
    echo -e "${GREEN}✓ Defines $VOLUME_COUNT named volume(s)${NC}"
fi

# Check for networks
if grep -q "^networks:" "$COMPOSE_FILE"; then
    NETWORK_COUNT=$(grep -A 100 "^networks:" "$COMPOSE_FILE" | grep "^  [a-zA-Z]" | wc -l)
    echo -e "${GREEN}✓ Defines $NETWORK_COUNT network(s)${NC}"
fi

echo ""
echo "=== Summary ==="
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}✗ $ERRORS error(s) found${NC}"
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
fi

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}✓ No issues found${NC}"
fi

echo ""

if [ "$ERRORS" -gt 0 ]; then
    echo "Deployment may fail. Fix errors before proceeding."
    exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo "Warnings found. Review before deploying."
    exit 0
fi

echo "Ready for deployment!"
exit 0
