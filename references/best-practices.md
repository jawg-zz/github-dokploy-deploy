# Dokploy Best Practices

## Environment Variables

**Critical:** Variables set in Dokploy UI are written to `.env` but NOT automatically injected into containers.

Must add to docker-compose.yml:

```yaml
# Option 1: Inject all variables
services:
  app:
    env_file:
      - .env

# Option 2: Inject specific variables
services:
  app:
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - API_KEY=${API_KEY}
```

**Shared variables** across services use `${{project.VARIABLE_NAME}}` syntax in service env tabs.

## Volume Persistence

Use `../files/` folder for bind mounts — NOT absolute paths (cleaned up on deploy):

```yaml
# ❌ Wrong - absolute paths get cleaned up
volumes:
  - "/folder:/path/in/container"

# ✅ Correct - use ../files for persistence
volumes:
  - "../files/my-database:/var/lib/mysql"

# ✅ Named volumes (for automated backups)
volumes:
  my-database:
services:
  app:
    volumes:
      - my-database:/var/lib/mysql
```

| Feature | Bind Mounts (`../files`) | Named Volumes |
|---------|--------------------------|---------------|
| Simple persistence | ✅ | ✅ |
| Direct host access | ✅ | ❌ |
| Automated backups | ❌ | ✅ |
| Docker-managed | ❌ | ✅ |

## Zero Downtime Deployments

Requires a health check endpoint. Example for Node.js app on port 3000:

1. Add health route to app:
   ```javascript
   app.get('/api/health', (req, res) => res.status(200).send('ok'));
   ```

2. Configure in Dokploy → Advanced → Cluster Settings → Swarm Settings:

   **Health Check:**
   ```json
   {
     "Test": ["CMD", "curl", "-f", "http://localhost:3000/api/health"],
     "Interval": 30000000000,
     "Timeout": 10000000000,
     "StartPeriod": 30000000000,
     "Retries": 3
   }
   ```

   **Update Config (for auto-rollback):**
   ```json
   {
     "Parallelism": 1,
     "Delay": 10000000000,
     "FailureAction": "rollback",
     "Order": "start-first"
   }
   ```

## Rollbacks

Two types:
1. **Docker Swarm** — Automatic, based on health check failures
2. **Registry-based** — Manual, stores each deployment image in registry for rollback to any version

Prerequisites for registry-based rollbacks:
- Docker registry configured (Docker Hub, GHCR, etc.)
- Registry credentials in Dokploy
- Application configured to push images during deploy

## Domain Configuration

**Recommended:** Use Dokploy's native domain management (Method 1).
- No Traefik labels needed in compose file
- Dokploy adds them automatically at deploy time
- Configure via Domains tab in UI

**Important:** If NOT using Isolated Deployments, manually add `dokploy-network` to services needing connectivity.

## SSL Certificates

- **Let's Encrypt:** Automatic with custom domains (recommended)
- **traefik.me:** HTTP only by default. For HTTPS, download certificates:
  - `https://traefik.me/fullchain.pem`
  - `https://traefik.me/privkey.pem`
  - Upload to Dokploy → Certificates → set cert provider to "None" in domain settings

## Watch Paths

Only deploy when specific files change. Supports glob patterns:

```
src/*           # Changes in src/ trigger deploy
src/index.js    # Only specific file
src/**/*.js     # All JS files recursively
!*.test.js      # Exclude test files
```

## Going to Production

**Build outside Dokploy** (recommended for production):
- Use CI/CD (GitHub Actions) to build and push Docker image
- In Dokploy, use the pre-built image instead of building on-server
- Prevents resource exhaustion during builds

Example GitHub Actions workflow:
```yaml
- uses: docker/build-push-action@v4
  with:
    push: true
    tags: username/repo:latest
```

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| "Bad Gateway" during deploy | No health check configured | Add health check for zero downtime |
| Variables not reaching container | Missing `env_file` or `environment` | Add to docker-compose.yml |
| Data lost on deploy | Using absolute path volumes | Use `../files/` or named volumes |
| Build timeout/freezing | Building on-server | Use CI/CD to build images |
| HTTPS not working on traefik.me | traefik.me is HTTP by default | Upload certificates manually |
