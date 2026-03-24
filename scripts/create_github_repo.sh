#!/bin/bash
# Create a GitHub repository and push local code

set -e

REPO_FULL_NAME="$1"  # Format: github.com/owner/repo or owner/repo
LOCAL_PATH="$2"
GITHUB_TOKEN="$3"
GITHUB_USERNAME="$4"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$REPO_FULL_NAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}Usage: $0 <repo-full-name> <local-path> <github-token> <github-username>${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 github.com/user/repo ./backend TOKEN username"
    echo "  $0 user/repo ./backend TOKEN username"
    exit 1
fi

# Parse repo name from full path
if [[ "$REPO_FULL_NAME" =~ github\.com/(.+)/(.+) ]]; then
    REPO_OWNER="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
elif [[ "$REPO_FULL_NAME" =~ (.+)/(.+) ]]; then
    REPO_OWNER="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
else
    echo -e "${RED}Error: Invalid repo format. Use 'owner/repo' or 'github.com/owner/repo'${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking if repository exists: $REPO_OWNER/$REPO_NAME${NC}"

# Check if repo already exists
CHECK_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME")

if [ "$CHECK_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ Repository already exists: $REPO_OWNER/$REPO_NAME${NC}"
    REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME.git"
else
    echo -e "${YELLOW}Creating new repository: $REPO_NAME${NC}"
    
    # Create repo via GitHub API
    RESPONSE=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/user/repos \
        -d "{\"name\":\"$REPO_NAME\",\"private\":false}")
    
    # Check for errors
    if echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); sys.exit(0 if 'message' not in data else 1)" 2>/dev/null; then
        :
    else
        ERROR=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('message', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
        echo -e "${RED}Error creating repository: $ERROR${NC}"
        exit 1
    fi
    
    # Extract repo URL
    REPO_URL=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('clone_url', ''))" 2>/dev/null || echo "")
    
    if [ -z "$REPO_URL" ]; then
        echo -e "${RED}Error: Could not extract repo URL${NC}"
        echo "$RESPONSE"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Repository created: $REPO_URL${NC}"
fi

# If local path provided, push code
if [ -n "$LOCAL_PATH" ]; then
    if [ ! -d "$LOCAL_PATH" ]; then
        echo -e "${RED}Error: Local path not found: $LOCAL_PATH${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Pushing code from $LOCAL_PATH to GitHub...${NC}"
    
    cd "$LOCAL_PATH"
    
    # Initialize git if not already
    if [ ! -d ".git" ]; then
        echo "  Initializing git repository..."
        git init -q
        git branch -M main
    fi
    
    # Configure git user if not set
    if [ -z "$(git config user.name)" ] && [ -n "$GITHUB_USERNAME" ]; then
        git config user.name "$GITHUB_USERNAME"
    fi
    if [ -z "$(git config user.email)" ] && [ -n "$GITHUB_USERNAME" ]; then
        git config user.email "$GITHUB_USERNAME@users.noreply.github.com"
    fi
    
    # Add remote if not exists
    if ! git remote get-url origin >/dev/null 2>&1; then
        echo "  Adding remote origin..."
        # Use token in URL for authentication
        REMOTE_URL="https://$GITHUB_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git"
        git remote add origin "$REMOTE_URL" 2>/dev/null || true
    else
        # Update remote URL with token
        REMOTE_URL="https://$GITHUB_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git"
        git remote set-url origin "$REMOTE_URL"
    fi
    
    # Stage all files
    echo "  Staging files..."
    git add -A
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        echo -e "${YELLOW}  No changes to commit (repository already up to date)${NC}"
    else
        # Commit
        echo "  Committing changes..."
        git commit -q -m "Initial commit from Dokploy deployment" || true
    fi
    
    # Push to GitHub
    echo "  Pushing to GitHub..."
    if git push -q -u origin main 2>&1 | grep -q "Everything up-to-date"; then
        echo -e "${GREEN}✓ Repository already up to date${NC}"
    else
        git push -q -u origin main --force 2>&1 || {
            echo -e "${RED}Error: Failed to push to GitHub${NC}"
            exit 1
        }
        echo -e "${GREEN}✓ Code pushed to GitHub${NC}"
    fi
fi

# Output repo URL for use in deployment
echo "$REPO_URL"
