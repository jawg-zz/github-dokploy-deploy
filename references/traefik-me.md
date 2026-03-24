# traefik.me Auto-Domain Support

Zero-configuration deployments using traefik.me wildcard DNS.

## What is traefik.me?

traefik.me is a free wildcard DNS service that resolves to your server's IP:
- `*.traefik.me` → `127.0.0.1`
- `*.192-168-1-100.traefik.me` → `192.168.1.100`
- `*.2001-db8--1.traefik.me` → `2001:db8::1`

**No DNS configuration needed** - domains work immediately.

## Usage

### Auto-Generate Domain

```bash
# Let the skill generate a traefik.me domain
bash scripts/setup_dokploy_compose.sh \
  https://dokploy.example.com \
  API_KEY \
  https://github.com/user/repo \
  PROJECT_ID \
  auto
```

Generates: `repo-a3f2c1.traefik.me` or `repo-a3f2c1-192-168-1-100.traefik.me`

### Manual Generation

```bash
# Generate domain for service
bash scripts/generate_traefik_domain.sh myapp
# Output: myapp-f7fc10.traefik.me

# Include server IP in domain
bash scripts/generate_traefik_domain.sh myapp 192.168.1.100
# Output: myapp-3dfd17-192-168-1-100.traefik.me
```

## Domain Format

```
{service-name}-{hash}-{slugified-ip}.traefik.me
```

- **service-name**: Truncated to 40 chars (DNS label limit)
- **hash**: 6-char random hex (prevents collisions)
- **slugified-ip**: Optional, dots/colons → dashes

## Examples

| Input | Output |
|-------|--------|
| `myapp` | `myapp-a3f2c1.traefik.me` |
| `myapp 192.168.1.100` | `myapp-a3f2c1-192-168-1-100.traefik.me` |
| `my-very-long-application-name` | `my-very-long-application-name-b4e8f2.traefik.me` |

## Important Notes

### HTTP Only (No SSL)

traefik.me domains use **HTTP by default** - no automatic SSL certificates:

```
✓ Domain created: http://myapp-a3f2c1.traefik.me (traefik.me - HTTP only)
```

**Why?** Let's Encrypt rate limits prevent wildcard SSL for public services like traefik.me.

**For HTTPS:** Use a custom domain with proper DNS.

### When to Use

✅ **Good for:**
- Development/testing
- Internal tools
- Quick demos
- Proof of concepts
- No DNS access

❌ **Not for:**
- Production apps (use custom domain)
- Apps requiring HTTPS
- Public-facing services
- SEO-sensitive sites

## Custom Domain vs traefik.me

| Feature | traefik.me | Custom Domain |
|---------|------------|---------------|
| Setup time | Instant | DNS propagation (minutes-hours) |
| SSL/HTTPS | ❌ HTTP only | ✅ Auto Let's Encrypt |
| Professional | ❌ | ✅ |
| DNS config | ❌ Not needed | ✅ Required |
| Production | ❌ | ✅ |

## Switching to Custom Domain

After testing with traefik.me, switch to a custom domain:

1. **Add DNS record:**
   ```
   A    myapp.example.com    →    your-server-ip
   ```

2. **Redeploy with custom domain:**
   ```bash
   bash scripts/setup_dokploy_compose.sh \
     https://dokploy.example.com \
     API_KEY \
     https://github.com/user/repo \
     PROJECT_ID \
     myapp.example.com
   ```

3. **SSL auto-configured** by Traefik/Let's Encrypt

## Troubleshooting

**Domain not resolving:**
```bash
# Test DNS resolution
nslookup myapp-a3f2c1.traefik.me
# Should return 127.0.0.1 or your server IP
```

**Service not accessible:**
- Check Dokploy dashboard for deployment status
- Verify health check is passing
- Check Traefik logs for routing issues

**Want HTTPS:**
- Use a custom domain instead
- Or manually upload SSL certificates in Dokploy UI

## Technical Details

### DNS Resolution

traefik.me uses wildcard DNS:
```
*.traefik.me                    → 127.0.0.1
*.192-168-1-100.traefik.me      → 192.168.1.100
*.2001-db8--1.traefik.me        → 2001:db8::1
```

### IP Slugification

IP addresses are converted to DNS-safe format:
- Dots (`.`) → Dashes (`-`)
- Colons (`:`) → Dashes (`-`)

Examples:
- `192.168.1.100` → `192-168-1-100`
- `2001:db8::1` → `2001-db8--1`

### Hash Generation

6-character random hex prevents collisions:
- Uses `openssl rand -hex 3`
- Probability of collision: ~1 in 16 million
- Regenerates on each deployment

## See Also

- **Best Practices**: `references/best-practices.md`
- **Domain Management**: `references/domains.md`
- **Compose Generator**: `references/compose-generator.md`
