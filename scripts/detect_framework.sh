#!/bin/bash
# Detect project framework and generate appropriate docker-compose.yml

set -e

PROJECT_DIR="${1:-.}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

detect_framework() {
    local dir="$1"
    
    # Check for Next.js
    if [[ -f "$dir/next.config.js" ]] || [[ -f "$dir/next.config.mjs" ]] || [[ -f "$dir/next.config.ts" ]]; then
        echo "nextjs"
        return
    fi
    
    # Check for NestJS
    if [[ -f "$dir/nest-cli.json" ]] || grep -q "@nestjs/core" "$dir/package.json" 2>/dev/null; then
        echo "nestjs"
        return
    fi
    
    # Check for Express
    if grep -q "\"express\"" "$dir/package.json" 2>/dev/null && ! grep -q "@nestjs" "$dir/package.json" 2>/dev/null; then
        echo "express"
        return
    fi
    
    # Check for React (Vite)
    if [[ -f "$dir/vite.config.js" ]] || [[ -f "$dir/vite.config.ts" ]]; then
        if grep -q "react" "$dir/package.json" 2>/dev/null; then
            echo "react-vite"
            return
        fi
        echo "vite"
        return
    fi
    
    # Check for Vue
    if grep -q "\"vue\"" "$dir/package.json" 2>/dev/null; then
        echo "vue"
        return
    fi
    
    # Check for Python/Django
    if [[ -f "$dir/manage.py" ]] && grep -q "django" "$dir/requirements.txt" 2>/dev/null; then
        echo "django"
        return
    fi
    
    # Check for Python/FastAPI
    if grep -q "fastapi" "$dir/requirements.txt" 2>/dev/null || grep -q "fastapi" "$dir/pyproject.toml" 2>/dev/null; then
        echo "fastapi"
        return
    fi
    
    # Check for Flask
    if grep -q "flask" "$dir/requirements.txt" 2>/dev/null || grep -q "flask" "$dir/pyproject.toml" 2>/dev/null; then
        echo "flask"
        return
    fi
    
    # Check for Go
    if [[ -f "$dir/go.mod" ]]; then
        echo "go"
        return
    fi
    
    # Check for Rust
    if [[ -f "$dir/Cargo.toml" ]]; then
        echo "rust"
        return
    fi
    
    # Generic Node.js
    if [[ -f "$dir/package.json" ]]; then
        echo "nodejs"
        return
    fi
    
    # Generic Python
    if [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/pyproject.toml" ]]; then
        echo "python"
        return
    fi
    
    echo "unknown"
}

detect_port() {
    local dir="$1"
    local framework="$2"
    
    # Check package.json for port in scripts
    if [[ -f "$dir/package.json" ]]; then
        local port=$(grep -oP 'PORT[=:]?\s*\K\d+' "$dir/package.json" 2>/dev/null | head -1)
        if [[ -n "$port" ]]; then
            echo "$port"
            return
        fi
    fi
    
    # Framework defaults
    case "$framework" in
        nextjs) echo "3000" ;;
        nestjs) echo "3000" ;;
        express) echo "3000" ;;
        react-vite|vite) echo "5173" ;;
        vue) echo "5173" ;;
        django) echo "8000" ;;
        fastapi) echo "8000" ;;
        flask) echo "5000" ;;
        go) echo "8080" ;;
        rust) echo "8080" ;;
        nodejs) echo "3000" ;;
        python) echo "8000" ;;
        *) echo "3000" ;;
    esac
}

generate_compose() {
    local framework="$1"
    local port="$2"
    local service_name="${3:-app}"
    
    cat > docker-compose.yml << EOF
services:
  $service_name:
    build: .
    ports:
      - "$port"
    restart: unless-stopped
EOF

    # Add framework-specific config
    case "$framework" in
        nextjs)
            cat >> docker-compose.yml << EOF
    environment:
      - NODE_ENV=production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
EOF
            ;;
        nestjs)
            cat >> docker-compose.yml << EOF
    environment:
      - NODE_ENV=production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
EOF
            ;;
        express)
            cat >> docker-compose.yml << EOF
    environment:
      - NODE_ENV=production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
EOF
            ;;
        react-vite|vite|vue)
            cat >> docker-compose.yml << EOF
    environment:
      - NODE_ENV=production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5173"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 256M
        reservations:
          cpus: '0.1'
          memory: 128M
EOF
            ;;
        django)
            cat >> docker-compose.yml << EOF
    environment:
      - DJANGO_SETTINGS_MODULE=config.settings
      - PYTHONUNBUFFERED=1
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
EOF
            ;;
        fastapi)
            cat >> docker-compose.yml << EOF
    environment:
      - PYTHONUNBUFFERED=1
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
EOF
            ;;
        flask)
            cat >> docker-compose.yml << EOF
    environment:
      - FLASK_ENV=production
      - PYTHONUNBUFFERED=1
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
EOF
            ;;
        go|rust)
            cat >> docker-compose.yml << EOF
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M
EOF
            ;;
        *)
            cat >> docker-compose.yml << EOF
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:$port/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
EOF
            ;;
    esac
}

# Main
FRAMEWORK=$(detect_framework "$PROJECT_DIR")
PORT=$(detect_port "$PROJECT_DIR" "$FRAMEWORK")

echo -e "${GREEN}Detected framework:${NC} $FRAMEWORK"
echo -e "${GREEN}Detected port:${NC} $PORT"

if [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    echo -e "${YELLOW}docker-compose.yml already exists. Skipping generation.${NC}"
    exit 0
fi

echo -e "${GREEN}Generating docker-compose.yml...${NC}"
generate_compose "$FRAMEWORK" "$PORT" "app"

echo -e "${GREEN}✓ Generated docker-compose.yml${NC}"
echo ""
echo "Review and customize as needed, then deploy with:"
echo "  bash scripts/setup_dokploy_compose.sh <dokploy-url> <api-key> <github-repo> <project-id> <subdomain>"
