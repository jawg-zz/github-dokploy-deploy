#!/bin/bash
# Generate secure random values for deployments
# Usage: generate_helpers.sh <type> [length]
# Types: password, hash, base64, jwt

TYPE="$1"
LENGTH="${2:-32}"

if [ -z "$TYPE" ]; then
    echo "Usage: $0 <type> [length]"
    echo ""
    echo "Types:"
    echo "  password [length]  - Alphanumeric password (default: 32 chars)"
    echo "  hash [length]      - Hex hash (default: 8 chars)"
    echo "  base64 [bytes]     - Base64 string (default: 32 bytes)"
    echo "  jwt                - JWT token with HMAC-SHA256"
    echo ""
    echo "Examples:"
    echo "  $0 password 16"
    echo "  $0 hash 8"
    echo "  $0 base64 32"
    echo "  $0 jwt"
    exit 1
fi

case "$TYPE" in
    password)
        # Generate alphanumeric password (lowercase)
        openssl rand -base64 $((LENGTH * 3 / 4)) | tr -dc 'a-z0-9' | head -c "$LENGTH"
        echo ""
        ;;
    
    hash)
        # Generate hex hash
        openssl rand -hex "$((LENGTH / 2))" | head -c "$LENGTH"
        echo ""
        ;;
    
    base64)
        # Generate base64 string
        openssl rand -base64 "$LENGTH" | tr -d "=+/" | head -c "$LENGTH"
        echo ""
        ;;
    
    jwt)
        # Generate JWT with HMAC-SHA256
        SECRET=$(openssl rand -hex 32)
        
        # Header
        HEADER='{"alg":"HS256","typ":"JWT"}'
        HEADER_B64=$(echo -n "$HEADER" | base64 | tr -d '=' | tr '+/' '-_')
        
        # Payload
        IAT=$(date +%s)
        EXP=$((IAT + 31536000))  # 1 year from now
        PAYLOAD="{\"iss\":\"dokploy\",\"iat\":$IAT,\"exp\":$EXP}"
        PAYLOAD_B64=$(echo -n "$PAYLOAD" | base64 | tr -d '=' | tr '+/' '-_')
        
        # Signature
        SIGNATURE=$(echo -n "${HEADER_B64}.${PAYLOAD_B64}" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64 | tr -d '=' | tr '+/' '-_')
        
        echo "${HEADER_B64}.${PAYLOAD_B64}.${SIGNATURE}"
        ;;
    
    *)
        echo "Error: Unknown type '$TYPE'"
        echo "Valid types: password, hash, base64, jwt"
        exit 1
        ;;
esac
