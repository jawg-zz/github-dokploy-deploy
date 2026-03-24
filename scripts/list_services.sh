#!/bin/bash
# List all services (compose, applications, databases) across all projects

set -e

DOKPLOY_URL="$1"
DOKPLOY_API_KEY="$2"
PROJECT_ID="${3:-}"  # Optional: filter by project ID

if [ -z "$DOKPLOY_URL" ] || [ -z "$DOKPLOY_API_KEY" ]; then
    echo "Usage: $0 <dokploy-url> <api-key> [project-id]"
    echo ""
    echo "If project-id is omitted, lists services from all projects."
    echo ""
    echo "Examples:"
    echo "  $0 https://main.spidmax.win API_KEY"
    echo "  $0 https://main.spidmax.win API_KEY IZQrpyqKizrOYJf-F5PYa"
    exit 1
fi

# Get list of projects to iterate
if [ -n "$PROJECT_ID" ]; then
    PROJECT_IDS="$PROJECT_ID"
else
    PROJECT_IDS=$(curl -s "$DOKPLOY_URL/api/trpc/project.all?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%7D%7D%7D" \
        -H "x-api-key: $DOKPLOY_API_KEY" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for p in data[0]['result']['data']['json']:
    print(p['projectId'])
" 2>/dev/null || echo "")
fi

if [ -z "$PROJECT_IDS" ]; then
    echo "No projects found."
    exit 0
fi

TOTAL_COMPOSE=0
TOTAL_APPS=0
TOTAL_DBS=0

for PID in $PROJECT_IDS; do
    PROJECT_DATA=$(curl -s "$DOKPLOY_URL/api/trpc/project.one?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22projectId%22%3A%22$PID%22%7D%7D%7D" \
        -H "x-api-key: $DOKPLOY_API_KEY")

    echo "$PROJECT_DATA" | python3 -c "
import sys, json

data = json.load(sys.stdin)
proj = data[0]['result']['data']['json']
print(f\"\\n📦 Project: {proj['name']} ({proj['projectId']})\")

for env in proj.get('environments', []):
    env_name = env.get('name', 'unknown')
    env_id = env.get('environmentId', '')

    # Compose services
    compose = env.get('compose', [])
    if compose:
        print(f\"\\n  🐳 Compose Services ({len(compose)}):\" )
        for c in compose:
            status = c.get('composeStatus', 'unknown')
            status_icon = {'done': '✅', 'running': '🚀', 'error': '❌', 'idle': '⏸️', 'building': '🔨'}.get(status, '❓')
            domains = [d.get('host', '') for d in c.get('domains', [])] if c.get('domains') else []
            domain_str = ', '.join(domains) if domains else 'no domain'
            repo = c.get('repository', '')
            repo_str = f' | repo: {repo}' if repo else ''
            print(f\"    {status_icon} {c['name']} | {c['composeId']} | {status} | {domain_str}{repo_str}\")

    # Applications
    apps = env.get('applications', [])
    if apps:
        print(f\"\\n  📱 Applications ({len(apps)}):\" )
        for a in apps:
            status = a.get('applicationStatus', 'unknown')
            status_icon = {'done': '✅', 'running': '🚀', 'error': '❌', 'idle': '⏸️', 'building': '🔨'}.get(status, '❓')
            domains = [d.get('host', '') for d in a.get('domains', [])] if a.get('domains') else []
            domain_str = ', '.join(domains) if domains else 'no domain'
            print(f\"    {status_icon} {a['name']} | {a.get('applicationId', '?')} | {status} | {domain_str}\")

    # Databases
    db_types = {
        'postgres': ('postgres', '🐘'),
        'mysql': ('mysql', '🐬'),
        'mariadb': ('mariadb', '🦭'),
        'mongo': ('mongo', '🍃'),
        'redis': ('redis', '🔴')
    }

    has_dbs = False
    for db_key, (db_type, icon) in db_types.items():
        dbs = env.get(db_key, [])
        if dbs:
            if not has_dbs:
                print(f\"\\n  🗄️  Databases:\")
                has_dbs = True
            for db in dbs:
                print(f\"    {icon} {db['name']} | {db.get(db_type + 'Id', db.get(db_key + 'Id', '?'))} | {db_type}\")

# Summary
total_data = data[0]['result']['data']['json']
" 2>/dev/null

    # Count totals for summary
    COMPOSE_COUNT=$(echo "$PROJECT_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
proj = data[0]['result']['data']['json']
count = 0
for env in proj.get('environments', []):
    count += len(env.get('compose', []))
print(count)
" 2>/dev/null || echo "0")

    APP_COUNT=$(echo "$PROJECT_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
proj = data[0]['result']['data']['json']
count = 0
for env in proj.get('environments', []):
    count += len(env.get('applications', []))
print(count)
" 2>/dev/null || echo "0")

    DB_COUNT=$(echo "$PROJECT_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
proj = data[0]['result']['data']['json']
count = 0
for env in proj.get('environments', []):
    for db_type in ['postgres', 'mysql', 'mariadb', 'mongo', 'redis']:
        count += len(env.get(db_type, []))
print(count)
" 2>/dev/null || echo "0")

    TOTAL_COMPOSE=$((TOTAL_COMPOSE + COMPOSE_COUNT))
    TOTAL_APPS=$((TOTAL_APPS + APP_COUNT))
    TOTAL_DBS=$((TOTAL_DBS + DB_COUNT))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary: $TOTAL_COMPOSE compose services | $TOTAL_APPS applications | $TOTAL_DBS databases"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
