# Compose Template Generator

Generates production-ready docker-compose.yml files following Dokploy best practices.

## Quick Start

```bash
bash scripts/generate_compose.sh <template-type> [options]
```

## Templates

### Node.js + PostgreSQL
```bash
bash scripts/generate_compose.sh node --name myapp --port 3000
```

Generates:
- Node.js app service with health check
- PostgreSQL 16 with persistent volume
- Environment variables with secure passwords
- Proper restart policies and depends_on

### Full-Stack (Next.js + PostgreSQL + Redis)
```bash
bash scripts/generate_compose.sh fullstack --name webapp --cache redis
```

Includes:
- App service
- PostgreSQL database
- Redis cache
- All environment variables configured

### Python + Database
```bash
bash scripts/generate_compose.sh python --name api --db mysql --port 8000
```

Supports:
- PostgreSQL (default)
- MySQL
- MongoDB

### Static Site
```bash
bash scripts/generate_compose.sh static --name mysite --db none
```

Nginx-based static site with:
- Bind mount to `../files/html`
- Health check
- No database

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--name <name>` | Service name | `app` |
| `--port <port>` | Application port | `3000` |
| `--db <type>` | Database: `postgres`, `mysql`, `mongodb`, `none` | `postgres` |
| `--cache <type>` | Cache: `redis`, `none` | `none` |
| `--output <file>` | Output file | `docker-compose.yml` |

## Generated Files

### docker-compose.yml
Production-ready compose file with:
- ✓ Health checks on all services
- ✓ Restart policies (`unless-stopped`)
- ✓ Named volumes for persistence
- ✓ Environment variable substitution
- ✓ Proper service dependencies
- ✓ Alpine images where available

### docker-compose.env.example
Environment variables to set in Dokploy UI:
- Secure random passwords (32 chars)
- Database connection strings
- Cache URLs
- Application config

## Best Practices Applied

1. **Environment Variables**
   - Uses `${VARIABLE}` syntax
   - No hardcoded secrets
   - Generates secure random passwords

2. **Health Checks**
   - All services have health checks
   - Proper intervals and timeouts
   - Start periods for slow services

3. **Volumes**
   - Named volumes for databases
   - Bind mounts use `../files/` prefix
   - Persistent across deployments

4. **Restart Policies**
   - `unless-stopped` on all services
   - Survives host reboots

5. **Dependencies**
   - Proper `depends_on` ordering
   - Database starts before app

6. **Images**
   - Alpine variants for smaller size
   - Pinned major versions (postgres:16, redis:7)
   - Official images only

## Examples

### Node.js API with PostgreSQL
```bash
bash scripts/generate_compose.sh node --name api --port 8080
```

### Python FastAPI with MongoDB + Redis
```bash
bash scripts/generate_compose.sh python \
  --name fastapi \
  --port 8000 \
  --db mongodb \
  --cache redis
```

### Static Marketing Site
```bash
bash scripts/generate_compose.sh static \
  --name marketing \
  --db none
```

## Validation

The generator automatically validates the output using `validate_deployment.sh`:
- Checks YAML structure
- Verifies required fields
- Warns about missing health checks
- Detects hardcoded secrets

## Next Steps After Generation

1. **Review the compose file**
   ```bash
   cat docker-compose.yml
   ```

2. **Copy environment variables to Dokploy**
   - Go to Dokploy UI → Your Service → Environment tab
   - Paste contents of `docker-compose.env.example`

3. **Create Dockerfile** (if using `build: .`)
   ```dockerfile
   FROM node:20-alpine
   WORKDIR /app
   COPY package*.json ./
   RUN npm ci --production
   COPY . .
   EXPOSE 3000
   CMD ["node", "index.js"]
   ```

4. **Add health endpoint** to your app
   ```javascript
   app.get('/health', (req, res) => res.status(200).send('ok'));
   ```

5. **Deploy**
   ```bash
   bash scripts/setup_dokploy_compose.sh \
     https://dokploy.example.com \
     API_KEY \
     https://github.com/user/repo \
     PROJECT_ID \
     myapp.example.com
   ```

## Customization

Edit the generated `docker-compose.yml` to:
- Add more services
- Customize health checks
- Add volumes or networks
- Change image versions
- Add build arguments

The generator creates a starting point — feel free to modify for your needs.

## Troubleshooting

**Missing health endpoint:**
```
Error: Health check failed
```
Add a `/health` route to your application.

**Environment variables not working:**
```
Error: DATABASE_URL is undefined
```
Make sure you copied the `.env.example` contents to Dokploy UI.

**Volume data lost:**
```
Error: Database reset on deploy
```
Check that volumes are named (not bind mounts with absolute paths).
