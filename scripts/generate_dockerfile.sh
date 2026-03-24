#!/bin/bash
# Generate production-ready Dockerfile based on framework detection

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

generate_dockerfile() {
    local framework="$1"
    
    case "$framework" in
        nextjs)
            cat > Dockerfile << 'EOF'
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies
COPY package.json package-lock.json* ./
RUN npm ci

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Disable telemetry during build
ENV NEXT_TELEMETRY_DISABLED 1

RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]
EOF
            ;;
        nestjs)
            cat > Dockerfile << 'EOF'
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nestjs

COPY package*.json ./
RUN npm ci --only=production

COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist

USER nestjs

EXPOSE 3000

CMD ["node", "dist/main"]
EOF
            ;;
        express)
            cat > Dockerfile << 'EOF'
FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 expressjs

COPY package*.json ./
RUN npm ci --only=production

COPY --chown=expressjs:nodejs . .

USER expressjs

EXPOSE 3000

CMD ["node", "index.js"]
EOF
            ;;
        react-vite|vite|vue)
            cat > Dockerfile << 'EOF'
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Production stage with nginx
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html

# Custom nginx config for SPA
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html; \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF
            ;;
        django)
            cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN adduser --disabled-password --gecos '' django
RUN chown -R django:django /app
USER django

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "config.wsgi:application"]
EOF
            ;;
        fastapi)
            cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN adduser --disabled-password --gecos '' fastapi
RUN chown -R fastapi:fastapi /app
USER fastapi

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
            ;;
        flask)
            cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    FLASK_ENV=production

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

COPY . .

RUN adduser --disabled-password --gecos '' flask
RUN chown -R flask:flask /app
USER flask

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "app:app"]
EOF
            ;;
        go)
            cat > Dockerfile << 'EOF'
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Production stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
EOF
            ;;
        rust)
            cat > Dockerfile << 'EOF'
FROM rust:1.75-alpine AS builder

WORKDIR /app

RUN apk add --no-cache musl-dev

COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

COPY . .
RUN touch src/main.rs
RUN cargo build --release

# Production stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

COPY --from=builder /app/target/release/app .

EXPOSE 8080

CMD ["./app"]
EOF
            ;;
        nodejs)
            cat > Dockerfile << 'EOF'
FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nodeapp

COPY package*.json ./
RUN npm ci --only=production

COPY --chown=nodeapp:nodejs . .

USER nodeapp

EXPOSE 3000

CMD ["node", "index.js"]
EOF
            ;;
        python)
            cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN adduser --disabled-password --gecos '' pyapp
RUN chown -R pyapp:pyapp /app
USER pyapp

EXPOSE 8000

CMD ["python", "main.py"]
EOF
            ;;
        *)
            echo -e "${RED}Unknown framework. Cannot generate Dockerfile.${NC}"
            exit 1
            ;;
    esac
}

generate_dockerignore() {
    cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
.env
.env.local
.env.*.local
*.md
.vscode
.idea
.DS_Store
dist
build
coverage
.next
.cache
__pycache__
*.pyc
*.pyo
*.pyd
.Python
*.so
*.egg
*.egg-info
.pytest_cache
.mypy_cache
target
Cargo.lock
EOF
}

# Main
FRAMEWORK=$(detect_framework "$PROJECT_DIR")

echo -e "${GREEN}Detected framework:${NC} $FRAMEWORK"

if [[ -f "$PROJECT_DIR/Dockerfile" ]]; then
    echo -e "${YELLOW}Dockerfile already exists. Skipping generation.${NC}"
    exit 0
fi

if [[ "$FRAMEWORK" == "unknown" ]]; then
    echo -e "${RED}Could not detect framework. Please create Dockerfile manually.${NC}"
    exit 1
fi

echo -e "${GREEN}Generating Dockerfile...${NC}"
generate_dockerfile "$FRAMEWORK"

if [[ ! -f "$PROJECT_DIR/.dockerignore" ]]; then
    echo -e "${GREEN}Generating .dockerignore...${NC}"
    generate_dockerignore
fi

echo -e "${GREEN}✓ Generated Dockerfile for $FRAMEWORK${NC}"
echo ""
echo "Review and customize as needed, then build with:"
echo "  docker build -t myapp ."
