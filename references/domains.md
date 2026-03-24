# Domain Management

Add, remove, or list domains for deployed services.

## Quick Reference

```bash
# List domains
bash scripts/manage_domains.sh <dokploy-url> <api-key> <service-type> <service-id> list

# Add domain with SSL
bash scripts/manage_domains.sh <dokploy-url> <api-key> <service-type> <service-id> add example.com

# Remove domain
bash scripts/manage_domains.sh <dokploy-url> <api-key> <service-type> <service-id> remove example.com
```

Service types: `compose`, `application`

## Adding Domains

### What Happens

When you add a domain, the script:
1. Creates domain entry in Dokploy
2. Configures Let's Encrypt SSL certificate
3. Sets up automatic HTTPS redirect
4. Configures Traefik routing

### DNS Configuration Required

After adding a domain, configure DNS:

**A Record:**
```
example.com → your-server-ip
```

**CNAME (for subdomains):**
```
www.example.com → example.com
```

### SSL Certificate Issuance

Let's Encrypt certificates are issued automatically once:
1. DNS propagates (usually 5-60 minutes)
2. Domain resolves to your server
3. HTTP challenge completes

Check certificate status in Dokploy UI under Certificates.

## Multiple Domains

Add multiple domains to the same service:

```bash
# Add primary domain
bash scripts/manage_domains.sh $DOKPLOY $KEY compose $SERVICE_ID add example.com

# Add www subdomain
bash scripts/manage_domains.sh $DOKPLOY $KEY compose $SERVICE_ID add www.example.com

# Add custom subdomain
bash scripts/manage_domains.sh $DOKPLOY $KEY compose $SERVICE_ID add api.example.com
```

All domains route to the same service.

## Listing Domains

View all configured domains:

```bash
bash scripts/manage_domains.sh $DOKPLOY $KEY compose $SERVICE_ID list
```

Output shows:
- Domain name
- Domain ID
- SSL status

## Removing Domains

Remove a domain when no longer needed:

```bash
bash scripts/manage_domains.sh $DOKPLOY $KEY compose $SERVICE_ID remove example.com
```

This:
1. Removes domain from Dokploy
2. Stops routing traffic
3. Removes SSL certificate

DNS records remain unchanged (you must update DNS separately).

## Common Patterns

### Apex + WWW

```bash
# Add both apex and www
bash scripts/manage_domains.sh $DOKPLOY $KEY compose $SERVICE_ID add example.com
bash scripts/manage_domains.sh $DOKPLOY $KEY compose $SERVICE_ID add www.example.com
```

### Multiple Subdomains

```bash
# API subdomain
bash scripts/manage_domains.sh $DOKPLOY $KEY compose $SERVICE_ID add api.example.com

# Admin subdomain
bash scripts/manage_domains.sh $DOKPLOY $KEY compose $SERVICE_ID add admin.example.com
```

### Different TLDs

```bash
# .com
bash scripts/manage_domains.sh $DOKPLOY $KEY compose $SERVICE_ID add example.com

# .io
bash scripts/manage_domains.sh $DOKPLOY $KEY compose $SERVICE_ID add example.io
```

## Troubleshooting

### SSL Certificate Not Issued

**Check DNS:**
```bash
dig example.com
nslookup example.com
```

Ensure it resolves to your server IP.

**Check HTTP accessibility:**
```bash
curl -I http://example.com
```

Should return 200 or redirect.

**Wait for propagation:**
DNS changes can take up to 48 hours (usually much faster).

### Domain Not Routing

1. Verify domain is listed: `bash scripts/manage_domains.sh ... list`
2. Check service is running: `bash scripts/list_services.sh ...`
3. Review Traefik logs in Dokploy UI

### Certificate Renewal

Let's Encrypt certificates auto-renew before expiration. No action needed.

## Port Configuration

By default, domains route to port 80 of your service. If your app uses a different port, update in Dokploy UI:

1. Go to service → Domains
2. Edit domain
3. Change port number
4. Save

## Path-Based Routing

For path-based routing (e.g., `example.com/api` → service A, `example.com/app` → service B), configure in Dokploy UI:

1. Add domain to both services
2. Set different paths for each
3. Service A: path = `/api`
4. Service B: path = `/app`
