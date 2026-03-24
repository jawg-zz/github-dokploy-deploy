# Traefik Labels for Domain Configuration

Configure domains directly in your docker-compose.yml using Traefik labels.

## Why Use Traefik Labels?

✅ **Infrastructure as Code** - Domains defined in compose file  
✅ **Version controlled** - Changes tracked in git  
✅ **No manual UI configuration** - Automated deployment  
✅ **Multiple domains per service** - Easy to manage  
✅ **Flexible routing** - Path-based, host-based, etc.  

## Basic Example

```yaml
services:
  web:
    image: nginx:alpine
    networks:
      - dokploy-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"

networks:
  dokploy-network:
    external: true
```

## Required Labels

### 1. Enable Traefik
```yaml
- "traefik.enable=true"
```

### 2. Router Rule (Domain)
```yaml
- "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
```

### 3. Entrypoint (HTTP/HTTPS)
```yaml
# HTTPS (recommended)
- "traefik.http.routers.myapp.entrypoints=websecure"

# HTTP only
- "traefik.http.routers.myapp.entrypoints=web"

# Both HTTP and HTTPS
- "traefik.http.routers.myapp.entrypoints=web,websecure"
```

### 4. TLS/SSL (for HTTPS)
```yaml
- "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
```

### 5. Service Port
```yaml
- "traefik.http.services.myapp.loadbalancer.server.port=3000"
```

### 6. Network
```yaml
networks:
  dokploy-network:
    external: true
```

## Complete Examples

### Node.js App with HTTPS

```yaml
services:
  app:
    build: .
    networks:
      - dokploy-network
    environment:
      NODE_ENV: production
      PORT: 3000
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=3000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  dokploy-network:
    external: true
```

### Multiple Domains

```yaml
services:
  web:
    image: nginx:alpine
    networks:
      - dokploy-network
    labels:
      - "traefik.enable=true"
      # Primary domain
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`) || Host(`www.myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"

networks:
  dokploy-network:
    external: true
```

### Path-Based Routing

```yaml
services:
  api:
    build: ./api
    networks:
      - dokploy-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`example.com`) && PathPrefix(`/api`)"
      - "traefik.http.routers.api.entrypoints=websecure"
      - "traefik.http.routers.api.tls.certresolver=letsencrypt"
      - "traefik.http.services.api.loadbalancer.server.port=8080"
      # Strip /api prefix before forwarding
      - "traefik.http.middlewares.api-stripprefix.stripprefix.prefixes=/api"
      - "traefik.http.routers.api.middlewares=api-stripprefix"

  frontend:
    build: ./frontend
    networks:
      - dokploy-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(`example.com`)"
      - "traefik.http.routers.frontend.entrypoints=websecure"
      - "traefik.http.routers.frontend.tls.certresolver=letsencrypt"
      - "traefik.http.services.frontend.loadbalancer.server.port=3000"

networks:
  dokploy-network:
    external: true
```

### HTTP to HTTPS Redirect

```yaml
services:
  web:
    image: nginx:alpine
    networks:
      - dokploy-network
    labels:
      - "traefik.enable=true"
      # HTTP router (redirect to HTTPS)
      - "traefik.http.routers.myapp-http.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp-http.entrypoints=web"
      - "traefik.http.routers.myapp-http.middlewares=redirect-to-https"
      # HTTPS router
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"
      # Redirect middleware
      - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"
      - "traefik.http.middlewares.redirect-to-https.redirectscheme.permanent=true"

networks:
  dokploy-network:
    external: true
```

## Common Patterns

### WWW Redirect

```yaml
labels:
  - "traefik.enable=true"
  # Redirect www to non-www
  - "traefik.http.routers.myapp-www.rule=Host(`www.myapp.example.com`)"
  - "traefik.http.routers.myapp-www.entrypoints=websecure"
  - "traefik.http.routers.myapp-www.tls.certresolver=letsencrypt"
  - "traefik.http.routers.myapp-www.middlewares=redirect-to-non-www"
  # Main router
  - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
  - "traefik.http.services.myapp.loadbalancer.server.port=3000"
  # Redirect middleware
  - "traefik.http.middlewares.redirect-to-non-www.redirectregex.regex=^https://www\\.(.+)"
  - "traefik.http.middlewares.redirect-to-non-www.redirectregex.replacement=https://$${1}"
  - "traefik.http.middlewares.redirect-to-non-www.redirectregex.permanent=true"
```

### Custom Headers

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
  - "traefik.http.services.myapp.loadbalancer.server.port=3000"
  # Security headers
  - "traefik.http.middlewares.security-headers.headers.framedeny=true"
  - "traefik.http.middlewares.security-headers.headers.sslredirect=true"
  - "traefik.http.middlewares.security-headers.headers.stsincludesubdomains=true"
  - "traefik.http.middlewares.security-headers.headers.stspreload=true"
  - "traefik.http.middlewares.security-headers.headers.stsseconds=31536000"
  - "traefik.http.routers.myapp.middlewares=security-headers"
```

### Rate Limiting

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
  - "traefik.http.services.myapp.loadbalancer.server.port=3000"
  # Rate limit: 100 requests per second
  - "traefik.http.middlewares.rate-limit.ratelimit.average=100"
  - "traefik.http.middlewares.rate-limit.ratelimit.burst=50"
  - "traefik.http.routers.myapp.middlewares=rate-limit"
```

## Important Notes

### Router Names Must Be Unique

Each router needs a unique name across all services:

```yaml
# ❌ Wrong - same router name
service1:
  labels:
    - "traefik.http.routers.app.rule=Host(`app1.com`)"

service2:
  labels:
    - "traefik.http.routers.app.rule=Host(`app2.com`)"

# ✅ Correct - unique router names
service1:
  labels:
    - "traefik.http.routers.app1.rule=Host(`app1.com`)"

service2:
  labels:
    - "traefik.http.routers.app2.rule=Host(`app2.com`)"
```

### Network is Required

All services must be on `dokploy-network`:

```yaml
networks:
  dokploy-network:
    external: true
```

### DNS Must Point to Server

Before deployment, configure DNS:
```
A    myapp.example.com    →    your-dokploy-server-ip
```

### SSL Certificates

Let's Encrypt certificates are auto-provisioned when:
- Domain DNS is configured correctly
- `tls.certresolver=letsencrypt` is set
- Port 80 and 443 are accessible

## Troubleshooting

**Service not accessible:**
- Check router name is unique
- Verify service is on `dokploy-network`
- Confirm DNS is resolving correctly
- Check Traefik dashboard in Dokploy UI

**SSL certificate not provisioning:**
- Wait 2-5 minutes for Let's Encrypt
- Verify DNS points to correct IP
- Check port 80/443 are open
- Review Traefik logs in Dokploy

**404 errors:**
- Verify `Host()` rule matches your domain exactly
- Check service port matches your app
- Ensure `traefik.enable=true` is set

## See Also

- **Best Practices**: `references/best-practices.md`
- **Domain Management**: `references/domains.md`
- **Compose Generator**: `references/compose-generator.md`
