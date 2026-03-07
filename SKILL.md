---
name: github-dokploy-deploy
description: Automate project deployment workflow - initialize git repo, create GitHub repository, push code, and configure Dokploy webhook for automatic deployment on push. Supports both Dockerfile and docker-compose deployments with subdomain configuration. Use when user wants to deploy a project to Dokploy with GitHub integration.
---

# GitHub + Dokploy Auto-Deploy

Automates the full deployment pipeline: local project → GitHub → Dokploy.

Supports two deployment modes:
- **Dockerfile**: Single container application
- **Docker Compose**: Multi-container application with services

## Workflow

When a user wants to deploy a project:

1. **Initialize Git** (if not already)
2. **Create GitHub repo** (using GitHub API)
3. **Push code to GitHub**
4. **Configure Dokploy webhook** to deploy on push

## Prerequisites

Check these before starting:

```bash
# Git installed and configured
git --version
git config --global user.name || echo "Need git user.name"
git config --global user.email || echo "Need git user.email"

# GitHub CLI or API token available
gh auth status 2>/dev/null || echo "Need GitHub auth"
```

## Step 1: Git Setup

If project isn't a git repo:

```bash
cd /path/to/project
git init
git add .
git commit -m "Initial commit"
```

If git user not configured, ask user for:
- Name
- Email

Then configure:

```bash
git config --global user.name "User Name"
git config --global user.email "user@example.com"
```

## Step 2: Create GitHub Repository

Use the helper script:

```bash
scripts/create_github_repo.sh <repo-name> <github-token>
```

The script:
- Creates the repo via GitHub API
- Returns the repo URL
- Handles errors (repo exists, auth failed, etc.)

## Step 3: Push to GitHub

```bash
git remote add origin <repo-url>
git branch -M main
git push -u origin main
```

## Step 4: Configure Dokploy Deployment

### Option A: Dockerfile Deployment (Single Container)

Use for simple single-container apps:

```bash
scripts/setup_dokploy_webhook.sh <dokploy-url> <dokploy-api-key> <github-repo-url> <project-id>
```

**Example:**
```bash
scripts/setup_dokploy_webhook.sh \
  https://main.spidmax.win \
  iGItKcVDSIIjquwmxYxeKACnJIUguPooNzpRlOynIhCYTEWbWfujyWAWxvjqSDtL \
  https://github.com/jawg-zz/flask-test-app \
  IZQrpyqKizrOYJf-F5PYa
```

**Requirements:**
- Dockerfile in project root
- Valid Dokploy API token (from Settings → Server → API Tokens)
- Project ID (get from Dokploy UI or `project.all` endpoint)

### Option B: Docker Compose Deployment (Multi-Container)

Use for apps with multiple services (web + db, microservices, etc.):

```bash
scripts/setup_dokploy_compose.sh <dokploy-url> <dokploy-api-key> <github-repo-url> <project-id> <subdomain> [compose-file]
```

**Example:**
```bash
scripts/setup_dokploy_compose.sh \
  https://main.spidmax.win \
  iGItKcVDSIIjquwmxYxeKACnJIUguPooNzpRlOynIhCYTEWbWfujyWAWxvjqSDtL \
  https://github.com/jawg-zz/my-app \
  IZQrpyqKizrOYJf-F5PYa \
  myapp.spidmax.win \
  docker-compose.yml
```

**Requirements:**
- docker-compose.yml in project root (or specify path)
- Valid Dokploy API token
- Project ID
- Subdomain (will be configured with SSL)
- Service name from docker-compose.yml (e.g., "web", "app")

**Docker Compose Format:**
Dokploy handles routing automatically. Your compose file should:
- Use simple `ports:` declaration (just port number, no host mapping)
- No need for Traefik labels or explicit networks
- Example:
  ```yaml
  services:
    web:
      build: .
      ports:
        - 5000
      environment:
        - FLASK_ENV=production
      restart: unless-stopped
  ```

**Features:**
- Creates compose service in Dokploy
- Configures GitHub webhook for auto-deploy
- Sets up subdomain with HTTPS
- Enables auto-deploy on push to main

See `references/dokploy-api.md` for API details.

## Configuration Storage

Store user credentials in `/data/workspace/TOOLS.md`:

```markdown
### GitHub
- Token: ghp_xxxxx
- Username: username

### Dokploy
- URL: https://main.spidmax.win
- API Key: xxxxx
```

## Error Handling

Common issues:

- **GitHub auth failed**: Token expired or invalid
- **Repo already exists**: Ask if should use existing or rename
- **Dokploy API error**: Check API key and URL
- **Git not configured**: Prompt for user details

## Usage Examples

User: "Deploy this project to Dokploy"
→ Run full workflow

User: "Push this to GitHub and auto-deploy"
→ Run full workflow

User: "Set up auto-deployment for my app"
→ Run full workflow
