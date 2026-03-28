#!/bin/bash
# Validate docker-compose.yml for Dokploy deployment
# Checks for common issues that break Dokploy deployments

set -e

COMPOSE_FILE="${1:-docker-compose.yml}"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: $COMPOSE_FILE not found"
    exit 1
fi

echo "Validating $COMPOSE_FILE for Dokploy deployment..."
echo ""

WARNINGS=0
ERRORS=0
AUTO_FIX=false

# Check for --fix flag
if [ "$2" = "--fix" ]; then
    AUTO_FIX=true
    echo "🔧 Auto-fix mode enabled"
    echo ""
fi

# Check 1: Exposed ports (conflicts in Dokploy)
if grep -q "^\s*ports:" "$COMPOSE_FILE"; then
    echo "❌ ERROR: Found 'ports:' mappings in compose file"
    echo "   Dokploy uses Traefik for routing - exposed ports WILL conflict"
    echo "   Port mappings must be removed for Dokploy deployment"
    echo ""
    grep -n "^\s*ports:" "$COMPOSE_FILE" | while read -r line; do
        echo "   Line: $line"
    done
    echo ""
    
    if [ "$AUTO_FIX" = true ]; then
        echo "🔧 Removing port mappings..."
        # Remove ports: section and the following lines until next service/key
        sed -i '/^\s*ports:/,/^\s*[a-z_-]*:/{ /^\s*ports:/d; /^\s*-.*:[0-9]/d; }' "$COMPOSE_FILE"
        echo "   ✓ Port mappings removed"
        echo ""
    else
        echo "   Fix: Run with --fix flag to auto-remove, or manually delete port mappings"
        echo ""
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check 2: Missing Traefik labels for web services
if grep -q "^\s*build:" "$COMPOSE_FILE" || grep -q "image:.*node\|python\|nginx" "$COMPOSE_FILE"; then
    if ! grep -q "traefik.enable=true" "$COMPOSE_FILE"; then
        echo "❌ ERROR: No Traefik labels found"
        echo "   Web services MUST have Traefik labels for routing in Dokploy"
        echo "   Without labels, your service won't be accessible"
        echo ""
        
        if [ "$AUTO_FIX" = true ]; then
            echo "⚠️  Auto-fix for Traefik labels requires manual configuration"
            echo "   Reason: Domain name and service port must be specified"
            echo ""
        fi
        
        echo "   Required labels (add to your web service):"
        echo "     labels:"
        echo "       - \"traefik.enable=true\""
        echo "       - \"traefik.http.routers.myapp.rule=Host(\`myapp.example.com\`)\""
        echo "       - \"traefik.http.routers.myapp.entrypoints=websecure\""
        echo "       - \"traefik.http.routers.myapp.tls=true\""
        echo "       - \"traefik.http.services.myapp.loadbalancer.server.port=3000\""
        echo ""
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check 3: Missing dokploy-network
if ! grep -q "dokploy-network" "$COMPOSE_FILE"; then
    echo "❌ ERROR: Missing 'dokploy-network'"
    echo "   Services MUST connect to dokploy-network for Traefik routing"
    echo "   Without this network, Traefik cannot reach your services"
    echo ""
    
    if [ "$AUTO_FIX" = true ]; then
        echo "🔧 Adding dokploy-network..."
        
        # Add network definition at the end if not present
        if ! grep -q "^networks:" "$COMPOSE_FILE"; then
            echo "" >> "$COMPOSE_FILE"
            echo "networks:" >> "$COMPOSE_FILE"
            echo "  dokploy-network:" >> "$COMPOSE_FILE"
            echo "    external: true" >> "$COMPOSE_FILE"
            echo "   ✓ Network definition added"
        else
            echo "   ⚠️  Networks section exists - add dokploy-network manually:"
            echo "     dokploy-network:"
            echo "       external: true"
            ERRORS=$((ERRORS + 1))
        fi
        
        echo ""
        echo "   ⚠️  You must also add 'dokploy-network' to your service's networks list:"
        echo "     services:"
        echo "       app:"
        echo "         networks:"
        echo "           - dokploy-network"
        echo ""
    else
        echo "   Add to your service:"
        echo "     networks:"
        echo "       - dokploy-network"
        echo "   And at the bottom:"
        echo "     networks:"
        echo "       dokploy-network:"
        echo "         external: true"
        echo ""
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check 4: Hardcoded secrets
if grep -qE "password:\s*['\"]?[a-zA-Z0-9]{1,20}['\"]?\s*$" "$COMPOSE_FILE"; then
    echo "⚠️  WARNING: Possible hardcoded passwords detected"
    echo "   Use environment variables instead: \${DB_PASSWORD}"
    echo ""
    WARNINGS=$((WARNINGS + 1))
fi

# Check 5: Missing health checks on databases
if grep -q "image:.*postgres\|mysql\|mongo\|redis" "$COMPOSE_FILE"; then
    if ! grep -q "healthcheck:" "$COMPOSE_FILE"; then
        echo "⚠️  WARNING: Database services missing health checks"
        echo "   Add healthcheck to ensure app waits for DB to be ready"
        echo ""
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Check 6: Version field (obsolete)
if grep -q "^version:" "$COMPOSE_FILE"; then
    echo "ℹ️  INFO: 'version:' field is obsolete in Compose v2+"
    echo "   Safe to remove, but not critical"
    echo ""
fi

# Check 7: Absolute paths in volumes
if grep -qE "volumes:.*:/" "$COMPOSE_FILE"; then
    echo "⚠️  WARNING: Absolute paths in volume mounts"
    echo "   Use relative paths or named volumes for portability"
    echo ""
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -gt 0 ]; then
    echo "❌ Validation failed: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "⚠️  Validation passed with $WARNINGS warning(s)"
    echo "   Review warnings above - they may cause deployment issues"
    exit 0
else
    echo "✅ Validation passed - no issues found"
    exit 0
fi
