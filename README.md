# GitHub + Dokploy Auto-Deploy Skill

Automate the full deployment pipeline: local project → GitHub → Dokploy.

## Features

- 🚀 Automatic GitHub repository creation and push
- 🐳 Support for both Dockerfile and Docker Compose deployments
- 🌐 Subdomain configuration with SSL
- 🔄 Auto-deploy on push to main branch
- 🔗 GitHub provider integration
- ✅ Tested and production-ready

## Installation

### Option 1: Download the packaged skill

```bash
# Download the .skill file
wget https://github.com/jawg-zz/github-dokploy-deploy/raw/main/github-dokploy-deploy.skill

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

**Deploy with Docker Compose:**
```
Deploy this project to Dokploy with subdomain myapp.example.com
```

**Deploy with Dockerfile:**
```
Deploy this Flask app to Dokploy
```

**Full workflow:**
```
Create a GitHub repo for this project and deploy it to Dokploy with auto-deploy enabled
```

## How It Works

The skill handles the complete deployment workflow:

1. **Git Setup** - Initializes git if needed, configures user details
2. **GitHub Repository** - Creates a new repository via GitHub API
3. **Push Code** - Commits and pushes your code to GitHub
4. **Dokploy Configuration** - Creates compose/application service with GitHub integration
5. **Domain Setup** - Configures subdomain with SSL
6. **Auto-Deploy** - Enables automatic deployment on push to main

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
      - FLASK_ENV=production
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
- Check deployment logs in Dokploy UI
- Verify your docker-compose.yml or Dockerfile is correct
- Ensure the service name matches what's in your compose file

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - feel free to use and modify as needed.

## Credits

Created for OpenClaw by Max ⚡

Tested with:
- Dokploy (self-hosted deployment platform)
- GitHub API
- Docker & Docker Compose
