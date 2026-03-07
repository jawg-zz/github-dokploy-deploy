#!/bin/bash
# Extract port from docker-compose.yml

set -e

COMPOSE_FILE="$1"
SERVICE_NAME="${2:-web}"

if [ -z "$COMPOSE_FILE" ]; then
    echo "Usage: $0 <compose-file> [service-name]"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: File not found: $COMPOSE_FILE"
    exit 1
fi

# Extract port from compose file
# Handles formats like:
#   - 5000
#   - "5000"
#   - 5000:5000
#   - "8080:8080"

PORT=$(grep -A 20 "^  $SERVICE_NAME:" "$COMPOSE_FILE" | grep -A 10 "ports:" | grep -E "^\s+- " | head -1 | sed 's/.*- //' | sed 's/"//g' | sed 's/:.*//' | tr -d ' ')

if [ -z "$PORT" ]; then
    # Try expose instead
    PORT=$(grep -A 20 "^  $SERVICE_NAME:" "$COMPOSE_FILE" | grep -A 10 "expose:" | grep -E "^\s+- " | head -1 | sed 's/.*- //' | sed 's/"//g' | tr -d ' ')
fi

if [ -z "$PORT" ]; then
    echo "Error: Could not detect port for service '$SERVICE_NAME'"
    echo "Please specify port manually or check your docker-compose.yml"
    exit 1
fi

echo "$PORT"
