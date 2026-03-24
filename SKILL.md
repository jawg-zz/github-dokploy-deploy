---
name: github-dokploy-deploy
description: Deploy web apps and services to Dokploy via GitHub integration with Docker Compose. Supports subdomain configuration, SSL, and automatic deployment on push. Use when user asks to deploy, host, publish, launch, set up, or put a web app/service/project online. Covers full-stack apps, APIs, static sites, and any containerized service. All services (app, databases, workers) are defined in a single docker-compose.yml file. ALWAYS use this skill for deployment requests instead of manual Docker/container setup.
---

# GitHub + Dokploy Auto-Deploy

Automates: local project → GitHub → Dokploy Docker Compose deployment.

## Quick Start

```bash
# Step 1: List or create a project
scripts/list_or_create_project.sh <dokploy-url> <api-key> [new-project-name]

# Step 2: Deploy to the chosen project
scripts/setup_dokploy_compose.sh <dokploy-url> <api-key> <github-repo-url> <project-id> [subdomain] [service-name] [compose-file]

# Use 'auto' for subdomain to generate traefik.me domain (no DNS setup needed)
scripts/setup_dokploy_compose.sh <dokploy-url> <api-key> <github-repo-url> <project-id> auto
```

## Core Workflow

1. Check prerequisites (git, GitHub token, Dokploy API key)
2. Discover or create project (interactive selection)
3. Initialize git → Create GitHub repo → Push code
4. Deploy via compose script
5. Auto-configure: domain, SSL, health checks, auto-deploy webhook

## Docker Compose Structure

All services (app, databases, workers, etc.) are defined in a single `docker-compose.yml` file, just like Dokploy's built-in templates.

**Example: Full-stack app with database**

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  web:
    build: .
    ports:
      - 3000
    environment:
      DATABASE_URL: postgresql://postgres:${DB_PASSWORD}@postgres:5432/myapp
      NODE_ENV: production
    depends_on:
      - postgres
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
```

## Prerequisites

Projects need `docker-compose.yml` before deploying. Generate one following best practices:

```bash
# Generate from template
bash scripts/generate_compose.sh <template-type> [options]

# Examples:
bash scripts/generate_compose.sh node --name myapp --port 3000
bash scripts/generate_compose.sh fullstack --name webapp --cache redis
bash scripts/generate_compose.sh python --db mysql --port 8000
bash scripts/generate_compose.sh static --name mysite --db none
```

**Templates:** `node`, `node-redis`, `python`, `static`, `fullstack`, `custom`

See `references/compose-generator.md` for full documentation.

Or detect framework and generate:

```bash
bash scripts/detect_framework.sh [project-dir]
```

## Credentials

Store in TOOLS.md:

```markdown
### Dokploy
- URL: https://dokploy.example.com
- API Key: <api-key>

### GitHub
- Token: ghp_<token>
- Username: <username>
```

## Advanced Features

For optional features, see references:

- **Framework detection & code generation**: `references/framework-detection.md`
- **Deployment diagnostics**: `references/diagnostics.md`
- **Watch paths**: `references/watch-paths.md`
- **Domain management**: `references/domains.md`
- **Domain configuration fix**: `references/domain-fix.md` (Important: Port + Service Name required)
- **traefik.me auto-domains**: `references/traefik-me.md` (Zero-config deployments)

## Core Scripts

| Script | Purpose |
|--------|---------|
| `list_or_create_project.sh` | List existing projects or create new one |
| `setup_dokploy_compose.sh` | Deploy Docker Compose service |
| `list_services.sh` | List all services with status |
| `restart_service.sh` | Redeploy, start, or stop service |
| `get_logs.sh` | Fetch deployment logs |
| `update_env.sh` | View or update environment variables |
| `delete_service.sh` | Delete service |

## Service Management

```bash
# List services
bash scripts/list_services.sh <dokploy-url> <api-key>

# Redeploy
bash scripts/restart_service.sh <dokploy-url> <api-key> compose <service-id>

# View logs
bash scripts/get_logs.sh <dokploy-url> <api-key> compose <service-id>

# Update env vars
bash scripts/update_env.sh <dokploy-url> <api-key> <service-id> set 'VAR=value'
```
