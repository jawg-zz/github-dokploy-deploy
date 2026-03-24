#!/bin/bash
# Add traefik.me domain support for zero-config deployments
# Generates domains like: myapp-a3f2c1.traefik.me

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

generate_traefik_domain() {
    local service_name="$1"
    local server_ip="$2"
    
    # Generate 6-char hash
    local hash=$($SCRIPT_DIR/generate_helpers.sh hash 6)
    
    # Slugify IP (replace dots and colons with dashes)
    local slug_ip=$(echo "$server_ip" | tr '.:'  '-')
    
    # Truncate service name to 40 chars (DNS label limit is 63)
    local max_length=40
    local truncated_name="${service_name:0:$max_length}"
    
    # Build domain: service-hash-ip.traefik.me
    if [ -z "$slug_ip" ] || [ "$slug_ip" = "-" ]; then
        echo "${truncated_name}-${hash}.traefik.me"
    else
        echo "${truncated_name}-${hash}-${slug_ip}.traefik.me"
    fi
}

# If called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    SERVICE_NAME="${1:-app}"
    SERVER_IP="${2:-}"
    
    if [ -z "$SERVICE_NAME" ]; then
        echo "Usage: $0 <service-name> [server-ip]"
        echo ""
        echo "Examples:"
        echo "  $0 myapp"
        echo "  $0 myapp 192.168.1.100"
        echo "  $0 myapp 2001:db8::1"
        exit 1
    fi
    
    generate_traefik_domain "$SERVICE_NAME" "$SERVER_IP"
fi
