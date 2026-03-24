#!/bin/bash
# Parse deployment logs and suggest fixes for common issues

set -e

DOKPLOY_URL="$1"
API_KEY="$2"
SERVICE_TYPE="$3"
SERVICE_ID="$4"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ -z "$DOKPLOY_URL" ]] || [[ -z "$API_KEY" ]] || [[ -z "$SERVICE_TYPE" ]] || [[ -z "$SERVICE_ID" ]]; then
    echo -e "${RED}Usage: $0 <dokploy-url> <api-key> <service-type> <service-id>${NC}"
    echo ""
    echo "Service types: compose, application, postgres, mysql, mongodb, mariadb, redis"
    exit 1
fi

echo -e "${BLUE}Fetching deployment logs...${NC}"

# Get logs
LOGS=$(bash "$(dirname "$0")/get_logs.sh" "$DOKPLOY_URL" "$API_KEY" "$SERVICE_TYPE" "$SERVICE_ID" 100)

echo ""
echo -e "${YELLOW}Analyzing logs for common issues...${NC}"
echo ""

ISSUES_FOUND=0

# Check for port binding issues
if echo "$LOGS" | grep -qi "address already in use\|port.*already allocated\|bind.*failed"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Port binding issue detected${NC}"
    echo "   Problem: Another service is using the same port"
    echo "   Fix: Change the port in docker-compose.yml or stop the conflicting service"
    echo ""
fi

# Check for memory issues
if echo "$LOGS" | grep -qi "out of memory\|oom\|killed.*memory"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Out of memory${NC}"
    echo "   Problem: Container ran out of memory"
    echo "   Fix: Increase memory limits in docker-compose.yml:"
    echo "   deploy:"
    echo "     resources:"
    echo "       limits:"
    echo "         memory: 1G"
    echo ""
fi

# Check for missing dependencies
if echo "$LOGS" | grep -qi "module not found\|cannot find module\|modulenotfounderror"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Missing dependencies${NC}"
    echo "   Problem: Required packages not installed"
    echo "   Fix: Ensure package.json/requirements.txt is up to date and run:"
    echo "   npm install  (Node.js)"
    echo "   pip install -r requirements.txt  (Python)"
    echo ""
fi

# Check for database connection issues
if echo "$LOGS" | grep -qi "econnrefused\|connection refused\|could not connect to.*database\|database.*not found"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Database connection failed${NC}"
    echo "   Problem: Cannot connect to database"
    echo "   Fix:"
    echo "   1. Verify DATABASE_URL environment variable is set"
    echo "   2. Check database service is running"
    echo "   3. Ensure database host matches service name in compose"
    echo ""
fi

# Check for environment variable issues
if echo "$LOGS" | grep -qi "environment variable.*not set\|missing.*env\|undefined.*process.env"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Missing environment variables${NC}"
    echo "   Problem: Required environment variables not set"
    echo "   Fix: Add missing variables via:"
    echo "   bash scripts/update_env.sh $DOKPLOY_URL <api-key> $SERVICE_ID set 'VAR_NAME=value'"
    echo ""
fi

# Check for build failures
if echo "$LOGS" | grep -qi "build failed\|error.*building\|dockerfile.*error"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Build failed${NC}"
    echo "   Problem: Docker build encountered errors"
    echo "   Fix:"
    echo "   1. Check Dockerfile syntax"
    echo "   2. Ensure all COPY paths exist"
    echo "   3. Verify base image is accessible"
    echo ""
fi

# Check for permission issues
if echo "$LOGS" | grep -qi "permission denied\|eacces"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Permission denied${NC}"
    echo "   Problem: Insufficient permissions to access files/directories"
    echo "   Fix: Check file permissions in Dockerfile or add USER directive"
    echo ""
fi

# Check for network issues
if echo "$LOGS" | grep -qi "network.*not found\|could not resolve host"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Network issue${NC}"
    echo "   Problem: Cannot resolve hostnames or network not found"
    echo "   Fix: Ensure services are on the same Docker network"
    echo ""
fi

# Check for health check failures
if echo "$LOGS" | grep -qi "health check failed\|unhealthy"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Health check failing${NC}"
    echo "   Problem: Container health check endpoint not responding"
    echo "   Fix:"
    echo "   1. Verify health check endpoint exists (e.g., /health)"
    echo "   2. Increase start_period in health check config"
    echo "   3. Check application is listening on correct port"
    echo ""
fi

# Check for syntax errors
if echo "$LOGS" | grep -qi "syntaxerror\|syntax error\|unexpected token"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Syntax error in code${NC}"
    echo "   Problem: Code has syntax errors"
    echo "   Fix: Review recent code changes and fix syntax errors"
    echo ""
fi

# Check for missing files
if echo "$LOGS" | grep -qi "no such file or directory\|enoent"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Missing files${NC}"
    echo "   Problem: Required files not found"
    echo "   Fix:"
    echo "   1. Ensure all files are committed to git"
    echo "   2. Check .dockerignore isn't excluding needed files"
    echo "   3. Verify COPY paths in Dockerfile"
    echo ""
fi

# Check for timeout issues
if echo "$LOGS" | grep -qi "timeout\|timed out"; then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo -e "${RED}❌ Timeout${NC}"
    echo "   Problem: Operation took too long"
    echo "   Fix: Increase timeout values or optimize slow operations"
    echo ""
fi

if [[ $ISSUES_FOUND -eq 0 ]]; then
    echo -e "${GREEN}✓ No common issues detected${NC}"
    echo ""
    echo "If deployment is still failing, review full logs:"
    echo "  bash scripts/get_logs.sh $DOKPLOY_URL <api-key> $SERVICE_TYPE $SERVICE_ID"
else
    echo -e "${YELLOW}Found $ISSUES_FOUND potential issue(s)${NC}"
    echo ""
    echo "After fixing, redeploy with:"
    echo "  bash scripts/restart_service.sh $DOKPLOY_URL <api-key> $SERVICE_TYPE $SERVICE_ID"
fi
