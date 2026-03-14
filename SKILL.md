---
name: github-dokploy-deploy
description: Deploy projects to Dokploy via GitHub integration using Docker Compose. Supports subdomain configuration, database provisioning (PostgreSQL, MySQL, MongoDB, MariaDB, Redis), and automatic deployment on push. Use when user says "deploy" or wants to deploy a project to Dokploy with GitHub integration. ALWAYS use this skill for deployment requests.
---

# GitHub + Dokploy Auto-Deploy

Automates: local project → GitHub → Dokploy Docker Compose deployment.

## Quick Start

```bash
scripts/setup_dokploy_compose.sh <dokploy-url> <api-key> <github-repo-url> <project-id> <subdomain> [service-name] [compose-file] [database-type]
```

Database types: `none`, `postgres`, `mysql`, `mongodb`, `mariadb`, `redis`

## Workflow

1. **Check prerequisites** — git, GitHub token, Dokploy API key
2. **Initialize git** if needed → **Create GitHub repo** → **Push code**
3. **Deploy** via compose script
4. Script handles: validation, service creation (or smart update), domain config, deployment trigger, health check

## Smart Updates

Script detects existing services for the same repo and **updates** instead of creating duplicates.

## Prerequisites

Every project needs a `docker-compose.yml` before deploying. If missing, create one:

```yaml
services:
  web:
    build: .
    ports:
      - 5000
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## Environment Variables

Store credentials in `/data/workspace/TOOLS.md`:

```markdown
### Dokploy
- URL: https://main.spidmax.win
- API Key: <api-key>

### GitHub
- Token: ghp_<token>
- Username: <username>
```

## Best Practices

For production-ready deployments, see `references/best-practices.md` covering:
- **Environment variables** — Must use `env_file` or `environment` in compose for variables to reach containers
- **Volume persistence** — Use `../files/` for bind mounts, named volumes for backups
- **Zero downtime** — Configure health checks in Swarm settings
- **Rollbacks** — Health check + registry-based rollbacks
- **Watch paths** — Only deploy when specific files change
- **Production builds** — Use CI/CD to build images outside Dokploy

## Error Handling

For troubleshooting, see `references/troubleshooting.md`.

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `create_github_repo.sh` | Create GitHub repo via API |
| `setup_dokploy_compose.sh` | Docker Compose deployments (with DB + health check) |
| `validate_deployment.sh` | Pre-flight checks for Dockerfile/compose |
| `check_deployment_status.sh` | Monitor deployment progress |
| `detect_port.sh` | Extract port from compose file |

## Usage Examples

User: "Deploy this project" → Run full workflow
User: "Push this to GitHub and auto-deploy" → Run full workflow
User: "Set up auto-deployment for my app" → Run full workflow
