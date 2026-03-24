# Watch Paths Configuration

Configure selective deployments to trigger only on specific file changes.

## Quick Setup

```bash
# Watch only src directory
bash scripts/configure_watch_paths.sh <dokploy-url> <api-key> <service-type> <service-id> 'src/**'

# Watch multiple paths
bash scripts/configure_watch_paths.sh <dokploy-url> <api-key> <service-type> <service-id> 'src/**' 'package.json' 'Dockerfile'

# Exclude paths
bash scripts/configure_watch_paths.sh <dokploy-url> <api-key> <service-type> <service-id> 'src/**' '!docs/**' '!*.md'
```

Service types: `compose`, `application`

## Why Use Watch Paths?

Without watch paths, **every push triggers a rebuild**, even for:
- README updates
- Documentation changes
- Test file modifications
- CI configuration tweaks

Watch paths save time and resources by deploying only when relevant files change.

## Pattern Matching

### Wildcards

**Single directory:**
```bash
'src/*'           # Files directly in src/
'*.js'            # All .js files in root
```

**Recursive:**
```bash
'src/**'          # All files in src/ and subdirectories
'**/*.ts'         # All TypeScript files anywhere
```

### Negation

Exclude specific paths:
```bash
'src/**' '!src/tests/**'        # src/ except tests
'**/*.js' '!**/*.test.js'       # All JS except test files
'!docs/**' '!*.md'              # Exclude docs and markdown
```

### Brace Expansion

Match multiple alternatives:
```bash
'{src,lib}/**'                  # Files in src/ OR lib/
'*.{js,ts}'                     # .js or .ts files
'foo/{1..5}.md'                 # foo/1.md through foo/5.md
```

### Character Classes

**POSIX classes:**
```bash
'[[:alpha:]]*'                  # Files starting with letter
'[[:digit:]]*'                  # Files starting with number
```

**Regex classes:**
```bash
'foo-[1-5].js'                  # foo-1.js through foo-5.js
'[a-z]*.txt'                    # Files starting with lowercase letter
```

### Logical OR

```bash
'foo/(abc|xyz).js'              # foo/abc.js or foo/xyz.js
```

## Common Patterns

### Frontend Projects

```bash
# React/Vue/Next.js
'src/**' 'public/**' 'package.json' 'package-lock.json' '!src/**/*.test.js'
```

### Backend APIs

```bash
# Node.js/NestJS
'src/**' 'package.json' 'package-lock.json' '!src/**/*.spec.ts'
```

### Full-Stack Monorepo

```bash
# Watch both frontend and backend
'apps/**' 'packages/**' 'package.json' '!**/*.test.*' '!**/*.spec.*'
```

### Python Projects

```bash
# Django/FastAPI
'src/**' 'requirements.txt' 'pyproject.toml' '!**/__pycache__/**' '!**/*.pyc'
```

### Infrastructure as Code

```bash
# Only deploy on infrastructure changes
'Dockerfile' 'docker-compose.yml' '.dockerignore' 'nginx.conf'
```

## Example Workflow

**Before watch paths:**
- Update README.md → Full rebuild (5 minutes)
- Fix typo in docs → Full rebuild (5 minutes)
- Add test → Full rebuild (5 minutes)

**After watch paths:**
- Update README.md → No deployment
- Fix typo in docs → No deployment
- Add test → No deployment
- Update src/api.ts → Deployment triggered (5 minutes)

## Verification

After configuring, test by:
1. Push a change to an excluded path (e.g., README.md)
2. Verify no deployment triggered
3. Push a change to an included path (e.g., src/index.js)
4. Verify deployment triggered

## Supported Providers

Watch paths work with:
- GitHub (zero configuration)
- GitLab (requires auto-deploy setup)
- Bitbucket (requires auto-deploy setup)
- Gitea (requires auto-deploy setup)

For non-GitHub providers, see the Auto Deploy documentation first.
