# Domain Configuration Fix

## The Issue

Dokploy requires **two pieces of information** for domain routing to work:

1. **Port** - Which port the service listens on (e.g., 3000)
2. **Service Name** - Which service in the compose file to route to (e.g., "app")

Without both, Traefik cannot route traffic correctly, resulting in 404 errors.

## The Solution

The `manage_domains.sh` script has been updated to include both fields when adding domains:

```bash
{
  "composeId": "$SERVICE_ID",
  "host": "$DOMAIN",
  "path": "/",
  "port": 3000,              # ← Service port
  "serviceName": "app",      # ← Service name from compose
  "https": true,
  "certificateType": "letsencrypt"
}
```

## Important Notes

### Port Configuration

The script currently hardcodes `port: 3000` for all services. This works for:
- Express (default: 3000)
- Next.js (default: 3000)
- NestJS (default: 3000)

For other frameworks, you may need to manually update the domain port in Dokploy UI:
- React/Vite: 5173
- Django/FastAPI: 8000
- Flask: 5000
- Go/Rust: 8080

### Service Name

The script uses `serviceName: "app"` which matches the default service name in generated compose files.

If you use a different service name in your compose file, update the domain configuration accordingly.

## Workflow

1. **Deploy service** - Creates the compose service
2. **Add domain** - Use `manage_domains.sh` with correct port and service name
3. **Redeploy** - Trigger redeploy for Dokploy to pick up domain configuration

## Example

```bash
# Add domain with correct configuration
bash scripts/manage_domains.sh \
  https://dokploy.example.com \
  api-key \
  compose \
  service-id \
  add \
  myapp.example.com

# Domain is now configured with:
# - Port: 3000
# - Service name: "app"
# - SSL: Let's Encrypt
```

## Verification

Check domain configuration:

```bash
curl -s -X GET "https://dokploy.example.com/api/domain.one?domainId=<domain-id>" \
  -H "x-api-key: <api-key>" | jq '{host, port, serviceName}'
```

Should return:
```json
{
  "host": "myapp.example.com",
  "port": 3000,
  "serviceName": "app"
}
```

## Troubleshooting

**Still getting 404 after adding domain?**

1. Verify domain configuration has both port and serviceName
2. Check service is running (status: done)
3. Redeploy the service to pick up domain changes
4. Wait 30-60 seconds for Traefik to update routing
5. Check Dokploy UI logs for deployment errors
