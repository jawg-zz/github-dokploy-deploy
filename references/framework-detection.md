# Framework Detection & Code Generation

Auto-detect frameworks and generate production-ready configuration files.

## Dockerfile Generation

Generate optimized Dockerfiles based on detected framework:

```bash
bash scripts/generate_dockerfile.sh [project-dir]
```

### Supported Frameworks

- **Next.js**: Multi-stage build with standalone output, optimized for production
- **NestJS**: TypeScript compilation with production dependencies only
- **Express**: Minimal Node.js setup with non-root user
- **React/Vite/Vue**: Nginx-based static file serving
- **Django**: Python with gunicorn, PostgreSQL client included
- **FastAPI**: Python with uvicorn for async support
- **Flask**: Python with gunicorn for production
- **Go**: Multi-stage build for minimal final image
- **Rust**: Multi-stage build with musl for static binaries

### Features

- Multi-stage builds for smaller images
- Non-root users for security
- Framework-specific optimizations
- Auto-generates `.dockerignore`

## Docker Compose Generation

Generate production-ready compose files:

```bash
bash scripts/detect_framework.sh [project-dir]
```

### Generated Configuration

Each framework gets appropriate:
- Health checks (framework-specific endpoints)
- Resource limits (CPU/memory based on typical usage)
- Environment variables (NODE_ENV, PYTHONUNBUFFERED, etc.)
- Restart policies (unless-stopped)

### Resource Limits by Framework

**Heavy frameworks** (Next.js):
- Limit: 1 CPU, 1GB RAM
- Reservation: 0.5 CPU, 512MB RAM

**Medium frameworks** (NestJS, Express, Django, FastAPI, Flask):
- Limit: 0.5 CPU, 512MB RAM
- Reservation: 0.25 CPU, 256MB RAM

**Light frameworks** (React/Vite, Vue, Go, Rust):
- Limit: 0.25 CPU, 256MB RAM
- Reservation: 0.1 CPU, 128MB RAM

## Detection Logic

Framework detection checks in order:

1. **Next.js**: `next.config.js/mjs/ts`
2. **NestJS**: `nest-cli.json` or `@nestjs/core` in package.json
3. **Express**: `express` in package.json (without NestJS)
4. **React/Vite**: `vite.config.js/ts` + `react` in package.json
5. **Vue**: `vue` in package.json
6. **Django**: `manage.py` + `django` in requirements.txt
7. **FastAPI**: `fastapi` in requirements.txt or pyproject.toml
8. **Flask**: `flask` in requirements.txt or pyproject.toml
9. **Go**: `go.mod`
10. **Rust**: `Cargo.toml`

Falls back to generic Node.js or Python if package files exist.
