#!/bin/bash
# Generate docker-compose.yml following Dokploy best practices
# Usage: generate_compose.sh <template-type> [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_usage() {
    echo "Usage: $0 <template-type> [options]"
    echo ""
    echo "Template Types:"
    echo "  node           - Node.js app with PostgreSQL"
    echo "  node-redis     - Node.js app with PostgreSQL + Redis"
    echo "  python         - Python app with PostgreSQL"
    echo "  static         - Static site (Nginx)"
    echo "  fullstack      - Next.js + PostgreSQL + Redis"
    echo "  custom         - Interactive custom setup"
    echo ""
    echo "Options:"
    echo "  --name <name>          Service name (default: app)"
    echo "  --port <port>          Application port (default: 3000)"
    echo "  --db <type>            Database: postgres, mysql, mongodb, none (default: postgres)"
    echo "  --cache <type>         Cache: redis, none (default: none)"
    echo "  --output <file>        Output file (default: docker-compose.yml)"
    echo ""
    echo "Examples:"
    echo "  $0 node --name myapp --port 8080"
    echo "  $0 fullstack --name webapp"
    echo "  $0 python --db mysql --cache redis"
    exit 1
}

# Parse arguments
TEMPLATE_TYPE="$1"
shift || show_usage

SERVICE_NAME="app"
APP_PORT="3000"
DB_TYPE="postgres"
CACHE_TYPE="none"
OUTPUT_FILE="docker-compose.yml"

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            SERVICE_NAME="$2"
            shift 2
            ;;
        --port)
            APP_PORT="$2"
            shift 2
            ;;
        --db)
            DB_TYPE="$2"
            shift 2
            ;;
        --cache)
            CACHE_TYPE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            ;;
    esac
done

if [ -z "$TEMPLATE_TYPE" ]; then
    show_usage
fi

echo -e "${BLUE}=== Dokploy Compose Generator ===${NC}"
echo "Template: $TEMPLATE_TYPE"
echo "Service: $SERVICE_NAME"
echo "Port: $APP_PORT"
echo "Database: $DB_TYPE"
echo "Cache: $CACHE_TYPE"
echo "Output: $OUTPUT_FILE"
echo ""

# Generate environment variables
generate_env_vars() {
    local db_type="$1"
    local cache_type="$2"
    
    echo "# Generated environment variables"
    echo "# Set these in Dokploy UI under Environment tab"
    echo ""
    
    if [ "$db_type" != "none" ]; then
        case "$db_type" in
            postgres)
                echo "DB_NAME=${SERVICE_NAME}_db"
                echo "DB_USER=postgres"
                echo "DB_PASSWORD=$($SCRIPT_DIR/generate_helpers.sh password 32)"
                echo "DATABASE_URL=postgresql://\${DB_USER}:\${DB_PASSWORD}@postgres:5432/\${DB_NAME}"
                ;;
            mysql)
                echo "DB_NAME=${SERVICE_NAME}_db"
                echo "DB_USER=mysql"
                echo "DB_PASSWORD=$($SCRIPT_DIR/generate_helpers.sh password 32)"
                echo "DATABASE_URL=mysql://\${DB_USER}:\${DB_PASSWORD}@mysql:3306/\${DB_NAME}"
                ;;
            mongodb)
                echo "DB_NAME=${SERVICE_NAME}_db"
                echo "DB_USER=mongo"
                echo "DB_PASSWORD=$($SCRIPT_DIR/generate_helpers.sh password 32)"
                echo "DATABASE_URL=mongodb://\${DB_USER}:\${DB_PASSWORD}@mongodb:27017/\${DB_NAME}"
                ;;
        esac
        echo ""
    fi
    
    if [ "$cache_type" = "redis" ]; then
        echo "REDIS_PASSWORD=$($SCRIPT_DIR/generate_helpers.sh password 32)"
        echo "REDIS_URL=redis://:\${REDIS_PASSWORD}@redis:6379"
        echo ""
    fi
    
    echo "NODE_ENV=production"
    echo "PORT=$APP_PORT"
}

# Generate database service
generate_db_service() {
    local db_type="$1"
    
    case "$db_type" in
        postgres)
            cat << 'EOF'
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

EOF
            ;;
        mysql)
            cat << 'EOF'
  mysql:
    image: mysql:8-oracle
    environment:
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "${DB_USER}", "-p${DB_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

EOF
            ;;
        mongodb)
            cat << 'EOF'
  mongodb:
    image: mongo:7
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${DB_USER}
      MONGO_INITDB_ROOT_PASSWORD: ${DB_PASSWORD}
      MONGO_INITDB_DATABASE: ${DB_NAME}
    volumes:
      - mongodb_data:/data/db
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

EOF
            ;;
    esac
}

# Generate cache service
generate_cache_service() {
    local cache_type="$1"
    
    if [ "$cache_type" = "redis" ]; then
        cat << 'EOF'
  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

EOF
    fi
}

# Generate app service based on template
generate_app_service() {
    local template="$1"
    local service_name="$2"
    local port="$3"
    local db_type="$4"
    local cache_type="$5"
    
    # Build depends_on array
    local depends=""
    if [ "$db_type" != "none" ]; then
        depends="      - $db_type"
    fi
    if [ "$cache_type" = "redis" ]; then
        if [ -n "$depends" ]; then
            depends="$depends\n      - redis"
        else
            depends="      - redis"
        fi
    fi
    
    case "$template" in
        node|node-redis|fullstack)
            cat << EOF
  $service_name:
    build: .
    ports:
      - $port
    environment:
      NODE_ENV: \${NODE_ENV}
      PORT: \${PORT}
EOF
            if [ "$db_type" != "none" ]; then
                echo "      DATABASE_URL: \${DATABASE_URL}"
            fi
            if [ "$cache_type" = "redis" ]; then
                echo "      REDIS_URL: \${REDIS_URL}"
            fi
            
            if [ -n "$depends" ]; then
                echo "    depends_on:"
                echo -e "$depends"
            fi
            
            cat << EOF
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:$port/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

EOF
            ;;
            
        python)
            cat << EOF
  $service_name:
    build: .
    ports:
      - $port
    environment:
      PYTHONUNBUFFERED: 1
EOF
            if [ "$db_type" != "none" ]; then
                echo "      DATABASE_URL: \${DATABASE_URL}"
            fi
            if [ "$cache_type" = "redis" ]; then
                echo "      REDIS_URL: \${REDIS_URL}"
            fi
            
            if [ -n "$depends" ]; then
                echo "    depends_on:"
                echo -e "$depends"
            fi
            
            cat << EOF
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:$port/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

EOF
            ;;
            
        static)
            cat << EOF
  $service_name:
    image: nginx:alpine
    ports:
      - 80
    volumes:
      - ../files/html:/usr/share/nginx/html:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3

EOF
            ;;
    esac
}

# Generate volumes section
generate_volumes() {
    local db_type="$1"
    local cache_type="$2"
    
    local has_volumes=false
    
    echo "volumes:"
    
    if [ "$db_type" = "postgres" ]; then
        echo "  postgres_data:"
        has_volumes=true
    elif [ "$db_type" = "mysql" ]; then
        echo "  mysql_data:"
        has_volumes=true
    elif [ "$db_type" = "mongodb" ]; then
        echo "  mongodb_data:"
        has_volumes=true
    fi
    
    if [ "$cache_type" = "redis" ]; then
        echo "  redis_data:"
        has_volumes=true
    fi
    
    if [ "$has_volumes" = false ]; then
        echo "  # No named volumes defined"
    fi
}

# Generate compose file
{
    echo "# Generated by Dokploy Compose Generator"
    echo "# Template: $TEMPLATE_TYPE"
    echo "# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo ""
    echo "services:"
    
    # App service
    generate_app_service "$TEMPLATE_TYPE" "$SERVICE_NAME" "$APP_PORT" "$DB_TYPE" "$CACHE_TYPE"
    
    # Database service
    if [ "$DB_TYPE" != "none" ]; then
        generate_db_service "$DB_TYPE"
    fi
    
    # Cache service
    if [ "$CACHE_TYPE" != "none" ]; then
        generate_cache_service "$CACHE_TYPE"
    fi
    
    # Volumes
    generate_volumes "$DB_TYPE" "$CACHE_TYPE"
    
} > "$OUTPUT_FILE"

echo -e "${GREEN}✓ Generated: $OUTPUT_FILE${NC}"
echo ""

# Generate .env.example
ENV_FILE="${OUTPUT_FILE%.yml}.env.example"
generate_env_vars "$DB_TYPE" "$CACHE_TYPE" > "$ENV_FILE"

echo -e "${GREEN}✓ Generated: $ENV_FILE${NC}"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review $OUTPUT_FILE"
echo "2. Copy $ENV_FILE to Dokploy Environment tab"
echo "3. Update Dockerfile if needed"
echo "4. Deploy with: scripts/setup_dokploy_compose.sh"
echo ""

# Validate the generated file
if [ -f "$SCRIPT_DIR/validate_deployment.sh" ]; then
    echo -e "${BLUE}Running validation...${NC}"
    echo ""
    bash "$SCRIPT_DIR/validate_deployment.sh" "$OUTPUT_FILE"
fi
