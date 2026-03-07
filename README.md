# GitHub + Dokploy Auto-Deploy Skill

Automate the full deployment pipeline: local project → GitHub → Dokploy.

## Features

- 🚀 Automatic GitHub repository creation and push
- 🐳 Support for both Dockerfile and Docker Compose deployments
- 🌐 Subdomain configuration with SSL
- 🔄 Auto-deploy on push to main branch
- 🔗 GitHub provider integration
- 🗄️ **NEW: Database provisioning** (PostgreSQL, MySQL, MongoDB, MariaDB, Redis)
- 🔐 **NEW: Environment variables management**
- ✅ **NEW: Pre-deployment validation**
- 📊 **NEW: Real-time deployment status tracking**
- 🔍 **NEW: Auto-detect ports from compose files**

## Installation

### Option 1: Download the packaged skill

```bash
# Download the .skill file
wget https://github.com/jawg-zz/github-dokploy-deploy/releases/download/v1.1.0/github-dokploy-deploy.skill

# Install to OpenClaw
mkdir -p ~/.openclaw/skills
cp github-dokploy-deploy.skill ~/.openclaw/skills/
```

### Option 2: Clone and use directly

```bash
# Clone the repository
git clone https://github.com/jawg-zz/github-dokploy-deploy.git

# Copy to OpenClaw skills directory
cp -r github-dokploy-deploy ~/workspace/skills/
```

## What's New in v1.1.0

### 🗄️ Database Provisioning
Automatically create and link databases to your applications:
- PostgreSQL, MySQL, MongoDB, MariaDB, Redis
- Secure credential generation
- Automatic `DATABASE_URL` injection

### ✅ Deployment Validation
Pre-flight checks before deployment:
- YAML/Dockerfile syntax validation
- Port configuration checks
- Best practices warnings

### 📊 Status Tracking
Monitor deployments in real-time:
- Follow mode to watch progress
- Clear status indicators
- Direct links to logs

### 🔧 Port Auto-Detection
Automatically detect ports from docker-compose.yml - no manual configuration needed!

## Prerequisites

Before using this skill, you need:

1. **Dokploy instance** with API access
2. **GitHub account** with personal access token
3. **GitHub provider configured in Dokploy** (Settings → Git Providers)

### Setup

1. **Get your Dokploy API key:**
   - Login to your Dokploy instance
   - Go to Settings → Server → API Tokens
   - Create a new token and save it

2. **Get your GitHub token:**
   - Go to https://github.com/settings/tokens/new
   - Create a token with `repo` and `admin:repo_hook` scopes
   - Save the token

3. **Configure in OpenClaw:**
   Add to your `TOOLS.md`:
   ```markdown
   ### Dokploy
   - URL: https://your-dokploy-instance.com
   - API Key: your-api-key

   ### GitHub
   - Token: your-github-token
   - Username: your-username
   - Email: your-email
   ```

## Usage

Once installed, the skill automatically triggers when you ask OpenClaw to deploy projects to Dokploy.

### Example Commands

**Deploy with Docker Compose and PostgreSQL:**
```
Deploy this project to Dokploy with a PostgreSQL database at myapp.example.com
```

**Deploy with validation:**
```
Validate and deploy this app to Dokploy
```

**Monitor deployment:**
```
Check the deployment status for my app
```

## Manual Usage

### Deploy with Database

```bash
scripts/setup_dokploy_compose_advanced.sh \
  https://main.spidmax.win \
  API_KEY \
  https://github.com/user/my-app \
  PROJECT_ID \
  myapp.example.com \
  web \
  docker-compose.yml \
  postgres
```

### Validate Before Deploying

```bash
scripts/validate_deployment.sh ./docker-compose.yml
```

### Monitor Deployment

```bash
scripts/check_deployment_status.sh \
  https://main.spidmax.win \
  API_KEY \
  COMPOSE_ID \
  true  # Follow mode
```

## Docker Compose Format

For docker-compose deployments, use this simple format (Dokploy handles routing automatically):

```yaml
version: '3.8'

services:
  web:
    build: .
    ports:
      - 5000
    environment:
      - DATABASE_URL
    restart: unless-stopped
```

No need for Traefik labels or explicit networks - Dokploy manages that for you.

## Troubleshooting

**"GitHub Provider not found"**
- Configure a GitHub provider in Dokploy UI (Settings → Git Providers)

**"UNAUTHORIZED" errors**
- Check that your Dokploy API key is valid and not expired
- Regenerate the token if needed

**Deployment fails**
- Run validation first: `scripts/validate_deployment.sh ./docker-compose.yml`
- Check deployment logs in Dokploy UI
- Verify your docker-compose.yml or Dockerfile is correct
- Ensure the service name matches what's in your compose file

**Database connection issues**
- Check that DATABASE_URL environment variable is set
- Verify database service is running in Dokploy UI
- Check database logs for connection errors

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Changelog

### v1.1.0 (2026-03-07)
- Added database provisioning (PostgreSQL, MySQL, MongoDB, MariaDB, Redis)
- Added environment variables management
- Added pre-deployment validation
- Added real-time deployment status tracking
- Added port auto-detection from compose files
- Improved error messages and user guidance

### v1.0.0 (2026-03-07)
- Initial release
- GitHub repository creation and push
- Dokploy webhook configuration
- Docker Compose and Dockerfile support
- Subdomain setup with SSL

## License

MIT License - feel free to use and modify as needed.

## Credits

Created for OpenClaw by Max ⚡

Tested with:
- Dokploy (self-hosted deployment platform)
- GitHub API
- Docker & Docker Compose
- PostgreSQL, MySQL, MongoDB, MariaDB, Redis
