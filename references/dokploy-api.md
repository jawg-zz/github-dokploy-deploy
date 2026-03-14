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

**Generate API Key:**
1. Login to Dokploy dashboard
2. Go to Settings → Server → API Tokens
3. Create new token
4. Copy and save securely

## tRPC Format

### Query (GET)

```bash
curl "https://main.spidmax.win/api/trpc/[procedure]?batch=1&input=%7B%220%22%3A%7B%7D%7D" \
  -H "x-api-key: <api-key>"
```

### Mutation (POST)

```bash
curl -X POST "https://main.spidmax.win/api/trpc/[procedure]?batch=1" \
  -H "x-api-key: <api-key>" \
  -H "Content-Type: application/json" \
  -d '{"0":{"json":{...}}}'
```

## Key Endpoints

### List Projects

```bash
curl "https://main.spidmax.win/api/trpc/project.all?batch=1&input=%7B%220%22%3A%7B%7D%7D" \
  -H "x-api-key: <api-key>"
```

**Response:**
```json
[{
  "result": {
    "data": {
      "json": [
        {"projectId": "ixqvvqxb", "name": "Default Project"}
      ]
    }
  }
}]
```

### Create Application

```bash
curl -X POST "https://main.spidmax.win/api/trpc/application.create?batch=1" \
  -H "x-api-key: <api-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "0": {
      "json": {
        "name": "app-name",
        "appName": "app-name",
        "projectId": "ixqvvqxb",
        "sourceType": "github",
        "repository": "owner/repo",
        "owner": "owner",
        "branch": "main",
        "buildType": "dockerfile",
        "dockerfilePath": "./Dockerfile",
        "autoDeploy": true
      }
    }
  }'
```

**Required Fields:**
- `name` - Application name
- `appName` - Display name
- `projectId` - Project ID (get from project.all)
- `sourceType` - "github", "gitlab", etc.
- `repository` - "owner/repo" format (no https://)
- `owner` - GitHub username/org
- `branch` - Branch to deploy
- `buildType` - "dockerfile", "nixpacks", "buildpack"
- `dockerfilePath` - Path to Dockerfile (e.g., "./Dockerfile")
- `autoDeploy` - true/false for auto-deploy on push

**Response:**
```json
[{
  "result": {
    "data": {
      "json": {
        "applicationId": "ixqvvqxb-app-name",
        "name": "app-name",
        ...
      }
    }
  }
}]
```

### List Applications

```bash
curl "https://main.spidmax.win/api/trpc/application.all?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22projectId%22%3A%22ixqvvqxb%22%7D%7D%7D" \
  -H "x-api-key: <api-key>"
```

### Deploy Application

```bash
curl -X POST "https://main.spidmax.win/api/trpc/deployment.create?batch=1" \
  -H "x-api-key: <api-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "0": {
      "json": {
        "applicationId": "app-id"
      }
    }
  }'
```

## Error Responses

```json
[{
  "error": {
    "message": "Error message",
    "code": "ERROR_CODE"
  }
}]
```

**Common Errors:**
- `UNAUTHORIZED` - Invalid API key
- `NOT_FOUND` - Resource doesn't exist
- `CONFLICT` - Resource already exists (e.g., app name taken)
- `BAD_REQUEST` - Invalid parameters

## Notes

- Repository format: `owner/repo` (not full URL)
- Owner must match repository owner
- Auto-deploy creates GitHub webhook automatically
- Dockerfile path is relative to repo root
- Default project ID: `ixqvvqxb` (check your instance)
