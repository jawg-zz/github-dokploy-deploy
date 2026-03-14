#!/bin/bash
# Validate docker-compose.yml or Dockerfile before deployment

set -e

FILE_PATH="$1"

if [ -z "$FILE_PATH" ]; then
    echo "Usage: $0 <path-to-dockerfile-or-compose>"
    exit 1
fi

if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File not found: $FILE_PATH"
    exit 1
fi

FILENAME=$(basename "$FILE_PATH")
VALIDATION_PASSED=true

echo "Validating $FILENAME..."

# Validate docker-compose.yml
if [[ "$FILENAME" == *"compose"* ]] || [[ "$FILENAME" == *".yml" ]] || [[ "$FILENAME" == *".yaml" ]]; then
    echo "Detected docker-compose file"
    
    # Check YAML syntax
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml" 2>/dev/null; then
            if ! python3 -c "import yaml; yaml.safe_load(open('$FILE_PATH'))" 2>/dev/null; then
                echo "❌ Invalid YAML syntax"
                VALIDATION_PASSED=false
            else
                echo "✓ YAML syntax valid"
            fi
        else
            echo "ℹ Info: PyYAML not installed, skipping YAML syntax check"
        fi
    else
        echo "ℹ Info: Python3 not available, skipping YAML syntax check"
    fi
    
    # Check for services section
    if ! grep -q "services:" "$FILE_PATH"; then
        echo "❌ Missing 'services:' section"
        VALIDATION_PASSED=false
    else
        echo "✓ Services section found"
    fi
    
    # Check for exposed ports
    if ! grep -qE "ports:|expose:" "$FILE_PATH"; then
        echo "⚠ Warning: No ports exposed (might be intentional)"
    else
        echo "✓ Ports configuration found"
    fi
    
    # Check for common issues
    if grep -q "host.docker.internal" "$FILE_PATH"; then
        echo "⚠ Warning: Using host.docker.internal (may not work in all environments)"
    fi

    # Check for version (optional in newer compose)
    if ! grep -q "version:" "$FILE_PATH"; then
        echo "ℹ Info: No version specified (using Compose v2+ format)"
    fi

    # Dokploy-specific: Check for env_file (needed for variable injection)
    if ! grep -q "env_file:" "$FILE_PATH" && ! grep -q "environment:" "$FILE_PATH"; then
        echo "⚠ Warning: No env_file or environment found"
        echo "  Dokploy writes variables to .env but they won't reach containers"
        echo "  Add 'env_file: [.env]' or 'environment:' to your services"
    else
        echo "✓ Environment variable injection configured"
    fi

    # Dokploy-specific: Check for absolute path volumes (get cleaned up)
    if grep -qE '^\s*-\s*/' "$FILE_PATH" | grep -qE '^\s*-\s*/[a-z]'; then
        echo "⚠ Warning: Absolute path volumes detected"
        echo "  Absolute paths may be cleaned up during deployments"
        echo "  Use '../files/' for bind mounts or named volumes instead"
    fi

    # Dokploy-specific: Check for health check endpoint
    if ! grep -q "healthcheck:" "$FILE_PATH" && ! grep -qE "HEALTHCHECK" "$FILE_PATH"; then
        echo "⚠ Warning: No health check configured"
        echo "  Add health checks for zero downtime deployments and auto-rollback"
        echo "  See references/best-practices.md for configuration"
    else
        echo "✓ Health check configured"
    fi

    # Dokploy-specific: Check for restart policy
    if ! grep -q "restart:" "$FILE_PATH"; then
        echo "ℹ Info: No restart policy specified (consider 'restart: unless-stopped')"
    else
        echo "✓ Restart policy found"
    fi

    # Dokploy-specific: Check for .dockerignore reminder
    if [ ! -f ".dockerignore" ] && [ -f "Dockerfile" ]; then
        echo "ℹ Info: No .dockerignore file found (may cause large build contexts)"
    fi

# Validate Dockerfile
elif [[ "$FILENAME" == "Dockerfile"* ]]; then
    echo "Detected Dockerfile"
    
    # Check for FROM instruction
    if ! grep -q "^FROM" "$FILE_PATH"; then
        echo "❌ Missing FROM instruction"
        VALIDATION_PASSED=false
    else
        echo "✓ FROM instruction found"
    fi
    
    # Check for EXPOSE or port configuration
    if ! grep -qE "^EXPOSE|^CMD.*--port|^ENTRYPOINT.*--port" "$FILE_PATH"; then
        echo "⚠ Warning: No EXPOSE instruction found (port might not be documented)"
    else
        echo "✓ Port exposure found"
    fi
    
    # Check for common issues
    if grep -q "apt-get install" "$FILE_PATH" && ! grep -q "apt-get update" "$FILE_PATH"; then
        echo "⚠ Warning: apt-get install without apt-get update"
    fi
    
    if grep -q "ADD http" "$FILE_PATH"; then
        echo "⚠ Warning: Using ADD for URLs (consider using RUN curl/wget instead)"
    fi
    
    # Check for best practices
    if ! grep -q "WORKDIR" "$FILE_PATH"; then
        echo "ℹ Info: No WORKDIR specified (consider adding one)"
    fi
    
else
    echo "❌ Unknown file type: $FILENAME"
    echo "Expected: Dockerfile or docker-compose.yml"
    exit 1
fi

echo ""
if [ "$VALIDATION_PASSED" = true ]; then
    echo "✅ Validation passed!"
    exit 0
else
    echo "❌ Validation failed - please fix the errors above"
    exit 1
fi
