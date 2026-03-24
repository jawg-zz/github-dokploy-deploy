# Dokploy API Reference

## Base URL

```
https://main.spidmax.win/api/trpc
```

## Authentication

Dokploy uses **tRPC** (TypeScript RPC) protocol.

**Header:**
```
x-api-key: <api-key>
```

**IMPORTANT:** Use `x-api-key` header, NOT `Authorization: Bearer`

---

## tRPC Format

### Query (GET)

```bash
curl "https://main.spidmax.win/api/trpc/[procedure]?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B...params%7D%7D%7D" \
  -H "x-api-key: <api-key>"
```

### Mutation (POST)

```bash
curl -X POST "https://main.spidmax.win/api/trpc/[procedure]?batch=1" \
  -H "x-api-key: <api-key>" \
  -H "Content-Type: application/json" \
  -d '{"0":{"json":{...params}}}'
```

---

## Project Endpoints

### List All Projects

```bash
curl "https://main.spidmax.win/api/trpc/project.all?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%7D%7D%7D" \
  -H "x-api-key: $DOKPLOY_API_KEY"
```

**Returns:** Array of projects with `projectId`, `name`, `description`, `environments`.

### Get Single Project (with all services)

```bash
curl "https://main.spidmax.win/api/trpc/project.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22projectId%22%3A%22<PROJECT_ID>%22%7D%7D%7D" \
  -H "x-api-key: $DOKPLOY_API_KEY"
```

**Returns:** Project with environments, each containing:
- `applications` — standalone Dockerfile/Nixpacks apps
- `compose` — Docker Compose services
- `postgres`, `mysql`, `mariadb`, `mongo`, `redis` — managed databases

**Example — list all compose services:**

```bash
curl -s "..." | python3 -c "
import sys,json
data = json.load(sys.stdin)
proj = data[0]['result']['data']['json']
for env in proj.get('environments', []):
    for c in env.get('compose', []):
        print(f\"{c['name']} | {c['composeId']}\")
"
```

---

## Compose Endpoints

### Get Single Compose Service

```bash
curl "https://main.spidmax.win/api/trpc/compose.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22composeId%22%3A%22<COMPOSE_ID>%22%7D%7D%7D" \
  -H "x-api-key: $DOKPLOY_API_KEY"
```

### Create Compose Service

```bash
curl -X POST "https://main.spidmax.win/api/trpc/compose.create?batch=1" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "0": {
      "json": {
        "name": "service-name",
        "projectId": "<PROJECT_ID>",
        "environmentId": "<ENV_ID>",
        "sourceType": "github",
        "repository": "owner/repo",
        "branch": "main",
        "composePath": "docker-compose.yml",
        "autoDeploy": true
      }
    }
  }'
```

### Deploy / Redeploy Compose Service

```bash
curl -X POST "https://main.spidmax.win/api/trpc/compose.deploy?batch=1" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "0": {
      "json": {
        "composeId": "<COMPOSE_ID>"
      }
    }
  }'
```

### Update Compose Service

```bash
curl -X POST "https://main.spidmax.win/api/trpc/compose.update?batch=1" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "0": {
      "json": {
        "composeId": "<COMPOSE_ID>",
        "name": "updated-name",
        "branch": "main",
        "autoDeploy": true
      }
    }
  }'
```

### Delete Compose Service

```bash
curl -X POST "https://main.spidmax.win/api/trpc/compose.delete?batch=1" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "0": {
      "json": {
        "composeId": "<COMPOSE_ID>",
        "deleteVolumes": true
      }
    }
  }'
```

---

## Domain Endpoints

### Create/Assign Domain

```bash
curl -X POST "https://main.spidmax.win/api/trpc/domain.create?batch=1" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "0": {
      "json": {
        "serviceName": "<SERVICE_ID>",
        "host": "subdomain.example.com",
        "port": 80,
        "path": "",
        "containerPort": 3000
      }
    }
  }'
```

---

## Database Endpoints

### Create PostgreSQL

```bash
curl -X POST "https://main.spidmax.win/api/trpc/postgres.create?batch=1" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "0": {
      "json": {
        "name": "db-name",
        "projectId": "<PROJECT_ID>",
        "environmentId": "<ENV_ID>",
        "description": "",
        "image": "postgres:16",
        "postgresPassword": "secure-password",
        "postgresUser": "appuser",
        "postgresDb": "appdb"
      }
    }
  }'
```

### Create MySQL

```bash
curl -X POST "https://main.spidmax.win/api/trpc/mysql.create?batch=1" ...
```

### Create MongoDB

```bash
curl -X POST "https://main.spidmax.win/api/trpc/mongo.create?batch=1" ...
```

### Create MariaDB

```bash
curl -X POST "https://main.spidmax.win/api/trpc/mariadb.create?batch=1" ...
```

### Create Redis

```bash
curl -X POST "https://main.spidmax.win/api/trpc/redis.create?batch=1" ...
```

---

## GitHub Endpoints

### List GitHub Providers

```bash
curl "https://main.spidmax.win/api/trpc/github.githubProviders?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%7D%7D%7D" \
  -H "x-api-key: $DOKPLOY_API_KEY"
```

---

## Deployment Endpoints

### List Deployments (per application)

```bash
curl "https://main.spidmax.win/api/trpc/deployment.all?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22applicationId%22%3A%22<APP_ID>%22%7D%7D%7D" \
  -H "x-api-key: $DOKPLOY_API_KEY"
```

**Note:** Deployment history is also embedded directly in `compose.one` response under the `deployments` array.

---

## Service Action Endpoints

### Start Service

```bash
curl -X POST "https://main.spidmax.win/api/trpc/compose.start?batch=1" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"0":{"json":{"composeId":"<COMPOSE_ID>"}}}'
```

### Stop Service

```bash
curl -X POST "https://main.spidmax.win/api/trpc/compose.stop?batch=1" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"0":{"json":{"composeId":"<COMPOSE_ID>"}}}'
```

---

## Key IDs for This Instance

| Resource | Name | ID |
|----------|------|----|
| Project | Homelab | `IZQrpyqKizrOYJf-F5PYa` |
| Project | Spidmax | `7uD-1I9DPWWzD22M7utG5` |
| Environment | production (Homelab) | `WGaDZpZTZQmIHcsDH9DC1` |
| Environment | production (Spidmax) | (check via `project.one`) |

---

## Response Format

### Success

```json
[{
  "result": {
    "data": {
      "json": { ... }
    }
  }
}]
```

### Error

```json
[{
  "error": {
    "message": "Error description",
    "code": "NOT_FOUND | BAD_REQUEST | UNAUTHORIZED | CONFLICT",
    "data": { "code": "...", "httpStatus": 404 }
  }
}]
```

---

## Notes

- Repository format: `owner/repo` (not full URL)
- Auto-deploy creates GitHub webhook automatically
- Compose file path is relative to repo root
- `deleteVolumes: true` removes associated Docker volumes on delete
- Use `compose.deploy` to force-redeploy a service
- The `project.one` endpoint is the best way to get a full inventory of all services
