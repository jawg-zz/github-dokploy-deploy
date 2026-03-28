# Auto-Deploy Workflow

Dokploy services created by this skill have `autoDeploy: true` enabled by default, which means GitHub webhooks automatically trigger deployments on every push.

## How It Works

1. **Initial Setup** (one-time):
   ```bash
   bash scripts/setup_dokploy_compose.sh <dokploy-url> <api-key> <github-repo-url> <project-id>
   ```
   - Creates Dokploy compose service
   - Configures GitHub webhook
   - Triggers initial deployment

2. **Subsequent Updates** (automatic):
   ```bash
   git add .
   git commit -m "Update feature"
   git push
   ```
   - GitHub webhook fires on push
   - Dokploy automatically pulls latest code
   - Builds and deploys without manual intervention

## When to Use Manual Deployment

Use `restart_service.sh` only when:

- **Redeploying without code changes** (rebuild with same code)
- **Forcing a rebuild** (clear cache, retry failed deployment)
- **Auto-deploy is disabled** (not the default)

```bash
bash scripts/restart_service.sh <dokploy-url> <api-key> compose <service-id>
```

## Common Mistake

❌ **Don't do this:**
```bash
git push
bash scripts/restart_service.sh ...  # Redundant!
```

This triggers **two deployments**:
1. Webhook deployment (from push)
2. Manual deployment (from restart_service.sh)

✅ **Do this instead:**
```bash
git push  # That's it - webhook handles deployment
```

## Disabling Auto-Deploy

If you want manual control over deployments:

1. Update the service via Dokploy API or UI
2. Set `autoDeploy: false`
3. Then use `restart_service.sh` for all deployments

## Checking Deployment Status

```bash
# List services and their status
bash scripts/list_services.sh <dokploy-url> <api-key>

# Get deployment logs
bash scripts/get_logs.sh <dokploy-url> <api-key> compose <service-id>
```

## Webhook Details

The webhook is automatically configured when you run `setup_dokploy_compose.sh`:

- **Trigger:** Push to `main` branch (configurable)
- **Action:** Pull latest code → Build → Deploy
- **Delay:** ~1-2 seconds after push
- **Retries:** Dokploy handles webhook failures automatically

## Troubleshooting

**Webhook not firing:**
- Check GitHub repo → Settings → Webhooks
- Verify webhook URL points to your Dokploy instance
- Check webhook delivery logs for errors

**Deployment not starting:**
- Verify `autoDeploy: true` in service config
- Check Dokploy logs for webhook processing errors
- Ensure GitHub has network access to Dokploy

**Multiple deployments:**
- You're probably calling `restart_service.sh` after pushing
- Remove manual trigger - webhook handles it
