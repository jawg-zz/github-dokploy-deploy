# Troubleshooting Guide

## Deployment Failures

### Build fails immediately
**Cause:** Invalid docker-compose.yml or missing build context
**Fix:** Run `scripts/validate_deployment.sh docker-compose.yml` to check for issues

### "No GitHub provider found"
**Cause:** GitHub not configured in Dokploy
**Fix:** Go to `{DOKPLOY_URL}/dashboard/settings/git-providers` and add GitHub

### "Environment not found"
**Cause:** Project ID doesn't match any existing project
**Fix:** Run `curl "{DOKPLOY_URL}/api/trpc/project.all?batch=1&input=%7B%220%22%3A%7B%7D%7D" -H "x-api-key: {API_KEY}"` to list projects

### Domain creation fails
**Cause:** Subdomain already taken or DNS misconfigured
**Fix:** Use a different subdomain, or configure manually in Dokploy UI

### Service created but not responding
**Possible causes:**
1. App port doesn't match docker-compose.yml ports config
2. App crashed on startup
3. Health check not configured

**Debug:** Check logs at `{DOKPLOY_URL}/dashboard/project/{PROJECT_ID}/services/compose/{COMPOSE_ID}`

## Smart Updates Not Working

If updating an existing service creates a duplicate instead:
1. Check that `repository` field matches exactly (case-sensitive)
2. The script matches by repo name — if you renamed the repo, delete the old service first

## Database Connection Issues

### App can't connect to database
**Cause:** Database container name doesn't match connection string
**Fix:** Use the `appName` from the database creation response as the hostname

### "DATABASE_URL" not set
**Cause:** Database creation was skipped or failed silently
**Fix:** Check if database was created in Dokploy UI, manually set env var if needed

## Rollback

Dokploy doesn't have a direct rollback API. To rollback:
1. Go to Dokploy UI → Project → Services → Compose
2. Click the deployment history tab
3. Find the last working deployment
4. Click "Redeploy" on that version

## SSL Certificate Issues

SSL is handled automatically by Traefik. If HTTPS isn't working:
1. Verify DNS points to Dokploy server
2. Ensure domain is configured with `https: true`
3. Check Traefik logs in Dokploy dashboard for certificate errors
