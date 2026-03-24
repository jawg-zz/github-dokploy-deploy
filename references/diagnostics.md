# Deployment Diagnostics

Intelligent log analysis with actionable fixes for common deployment failures.

## Quick Diagnosis

```bash
bash scripts/diagnose_deployment.sh <dokploy-url> <api-key> <service-type> <service-id>
```

Service types: `compose`, `application`, `postgres`, `mysql`, `mongodb`, `mariadb`, `redis`

## Detected Issues

### Port Binding Conflicts
**Symptoms:** "address already in use", "port already allocated", "bind failed"

**Fix:**
- Change port in docker-compose.yml
- Stop conflicting service
- Use different port mapping

### Out of Memory
**Symptoms:** "out of memory", "oom", "killed memory"

**Fix:**
```yaml
deploy:
  resources:
    limits:
      memory: 1G
```

### Missing Dependencies
**Symptoms:** "module not found", "cannot find module", "ModuleNotFoundError"

**Fix:**
- Update package.json or requirements.txt
- Run `npm install` or `pip install -r requirements.txt`
- Rebuild image

### Database Connection Failures
**Symptoms:** "ECONNREFUSED", "connection refused", "could not connect to database"

**Fix:**
1. Verify DATABASE_URL environment variable
2. Check database service is running
3. Ensure database host matches service name in compose

### Missing Environment Variables
**Symptoms:** "environment variable not set", "missing env", "undefined process.env"

**Fix:**
```bash
bash scripts/update_env.sh <dokploy-url> <api-key> <service-id> set 'VAR_NAME=value'
```

### Build Failures
**Symptoms:** "build failed", "error building", "Dockerfile error"

**Fix:**
1. Check Dockerfile syntax
2. Ensure all COPY paths exist
3. Verify base image is accessible

### Permission Denied
**Symptoms:** "permission denied", "EACCES"

**Fix:**
- Check file permissions in Dockerfile
- Add USER directive for non-root user
- Verify volume mount permissions

### Network Issues
**Symptoms:** "network not found", "could not resolve host"

**Fix:**
- Ensure services are on same Docker network
- Check DNS resolution
- Verify service names in compose

### Health Check Failures
**Symptoms:** "health check failed", "unhealthy"

**Fix:**
1. Verify health check endpoint exists (e.g., `/health`)
2. Increase `start_period` in health check config
3. Check application is listening on correct port

### Syntax Errors
**Symptoms:** "SyntaxError", "syntax error", "unexpected token"

**Fix:**
- Review recent code changes
- Run linter locally
- Check for typos

### Missing Files
**Symptoms:** "no such file or directory", "ENOENT"

**Fix:**
1. Ensure all files are committed to git
2. Check `.dockerignore` isn't excluding needed files
3. Verify COPY paths in Dockerfile

### Timeout Issues
**Symptoms:** "timeout", "timed out"

**Fix:**
- Increase timeout values
- Optimize slow operations
- Check for blocking code

## After Fixing

Redeploy the service:

```bash
bash scripts/restart_service.sh <dokploy-url> <api-key> <service-type> <service-id>
```

## Manual Log Review

If diagnostics don't find the issue, review full logs:

```bash
bash scripts/get_logs.sh <dokploy-url> <api-key> <service-type> <service-id> 100
```
