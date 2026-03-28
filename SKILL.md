---
name: github-dokploy-deploy
description: Deploy web apps and services to Dokploy via GitHub integration with Docker Compose. Supports subdomain configuration, SSL, and automatic deployment on push. Use when user asks to deploy, host, publish, launch, set up, or put a web app/service/project online. Covers full-stack apps, APIs, static sites, and any containerized service. All services (app, databases, workers) are defined in a single docker-compose.yml file. ALWAYS use this skill for deployment requests instead of manual Docker/container setup.
---

# GitHub + Dokploy Auto-Deploy

Automates: local project → GitHub → Dokploy Docker Compose deployment.

## Quick Start

```bash
# Step 1: Validate your compose file (recommended)
scripts/validate_compose.sh docker-compose.yml
# Or auto-fix common issues:
scripts/validate_compose.sh docker-compose.yml --fix

# Step 2: List or create a project
scripts/list_or_create_project.sh <dokploy-url> <api-key> [new-project-name]

# Step 3: Deploy to the chosen project
scripts/setup_dokploy_compose.sh <dokploy-url> <api-key> <github-repo-url> <project-id> [service-name] [compose-file]

# Note: Configure domains via Traefik labels in docker-compose.yml
# See references/traefik-labels.md for examples
```

## Core Workflow

1. **Validate compose file** (prevents deployment failures)
2. Check prerequisites (git, GitHub token, Dokploy API key)
3. Discover or create project (interactive selection)
4. Initialize git → Create GitHub repo → Push code
5. Deploy via compose script (initial deployment only)
6. Auto-configure: domain, SSL, health checks, auto-deploy webhook

**After initial setup:**
- Just `git commit && git push` to deploy updates
- Auto-deploy webhook triggers automatically on push
- No need to manually trigger deployments

**Manual redeployment (without new code):**
```bash
bash scripts/restart_service.sh <dokploy-url> <api-key> compose <service-id>
```

## Compose File Validation

**Always validate before deploying** to catch issues early:

```bash
# Check for issues
bash scripts/validate_compose.sh docker-compose.yml

# Auto-fix common issues (port mappings)
bash scripts/validate_compose.sh docker-compose.yml --fix
```

**What it checks:**

| Issue | Severity | Auto-fix |
|-------|----------|----------|
| Port mappings (`ports:`) | ❌ ERROR | ✅ Yes |
| Missing Traefik labels | ❌ ERROR | ❌ Manual |
| Missing dokploy-network | ❌ ERROR | ⚠️ Partial |
| Hardcoded secrets | ⚠️ WARNING | ❌ Manual |
| Missing health checks | ⚠️ WARNING | ❌ Manual |
| Obsolete version field | ℹ️ INFO | - |

**Why validation matters:**
- Port mappings cause "port already allocated" errors in Dokploy
- Missing Traefik labels = service won't be accessible
- Missing dokploy-network = Traefik can't route to your service

Validation is automatically run during deployment and will block if errors are found.

## Docker Compose Structure

All services (app, databases, workers, etc.) are defined in a single `docker-compose.yml` file, just like Dokploy's built-in templates.

**Domains are configured via Traefik labels** - no manual UI configuration needed.

**Important:** Domains configured via Traefik labels in docker-compose.yml will NOT appear in Dokploy's Domains UI. This is expected behavior - Traefik reads labels directly from containers. Your domains will work perfectly, they just won't be visible in the UI. This is the trade-off for infrastructure-as-code.

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
    networks:
      - dokploy-network
    environment:
      DATABASE_URL: postgresql://postgres:${DB_PASSWORD}@postgres:5432/myapp
      NODE_ENV: production
    depends_on:
      - postgres
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=3000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:

networks:
  dokploy-network:
    external: true
```

See `references/traefik-labels.md` for complete domain configuration examples.

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

- **Traefik labels for domains**: `references/traefik-labels.md` (Configure domains in compose file)
- **Framework detection & code generation**: `references/framework-detection.md`
- **Deployment diagnostics**: `references/diagnostics.md`
- **Watch paths**: `references/watch-paths.md`
- **Domain management**: `references/domains.md`
- **Domain configuration fix**: `references/domain-fix.md` (Important: Port + Service Name required)

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
