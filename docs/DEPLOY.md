# Deploy Configuration

Ephemeral PR preview deploys give humans a live environment to validate
agent work before merging. Production deploys push your code to live
infrastructure on every merge to `main`.

This template supports two deploy modes — pick the one that fits your workflow.

## Deploy modes

### Native service integration

The deploy provider's own Git hooks handle everything:

- **Production deploys** trigger automatically when you push to `main`
- **PR preview deploys** are created when you open or update a pull request
- **No GitHub Actions workflows** needed for deploys — the service watches your repo directly

Best when:
- You want zero-config deploys with minimal moving parts
- Your build is straightforward (single command, no multi-service orchestration)
- You're using Vercel, Netlify, or Cloudflare Pages (these have excellent native Git integration)

What `make init` does in native mode:
1. Runs the provider's link/init CLI (`vercel link`, `netlify init`, `wrangler pages project create`)
2. Generates the provider config file (`vercel.json`, `netlify.toml`, `wrangler.toml`)
3. Stores `DEPLOY_TOKEN` as a GitHub secret
4. Removes `pr-deploy.yml`, `pr-cleanup.yml`, and `deploy-production.yml` workflows
5. Replaces `scripts/deploy/` scripts with stubs (not needed)

### GitHub Actions scripts

Full control via custom deploy scripts triggered by GitHub Actions:

- **Production deploys** via `deploy-production.yml` → `scripts/deploy/production.sh`
- **PR preview deploys** via `pr-deploy.yml` → `scripts/deploy/pr-preview.sh`
- **PR cleanup** via `pr-cleanup.yml` → `scripts/deploy/pr-cleanup.sh`

Best when:
- You need custom build steps, multi-service orchestration, or environment-specific logic
- You want deploy logic versioned alongside your code
- You're using Fly.io (limited native Git support for PR previews)
- You need fine-grained control over the deploy pipeline

What `make init` does in scripts mode:
1. Stores `DEPLOY_TOKEN` as a GitHub secret
2. Sets `DEPLOY_PROVIDER`, `DEPLOY_PROJECT_ID`, and `DEPLOY_MODE` as GitHub repo variables
3. Configures build steps in `pr-deploy.yml` and `deploy-production.yml` based on your stack
4. Keeps all three deploy workflows and `scripts/deploy/` scripts active
5. Optionally generates a provider config file

## How it works (scripts mode)

1. Agent opens a PR
2. `pr-deploy.yml` workflow triggers and runs `scripts/deploy/pr-preview.sh`
3. The script deploys to your provider and writes the URL to `.deploy-artifacts/preview-url.txt`
4. The workflow comments the preview URL on the PR
5. When the PR is closed/merged, `pr-cleanup.yml` tears it down
6. On merge to `main`, `deploy-production.yml` runs `scripts/deploy/production.sh`

## How it works (native mode)

1. Agent opens a PR
2. The deploy service detects the PR branch and creates a preview deploy automatically
3. The service comments the preview URL on the PR (or shows it in its dashboard)
4. When the PR is merged, the service deploys to production automatically
5. No GitHub Actions involved — the service watches the repo directly

## Setup

If you ran `make init`, most of this is already done. This section is for manual setup
or for changing your configuration later.

### Scripts mode setup

#### 1. Set GitHub variables

In your repo Settings > Secrets and variables > Actions > Variables:

| Variable | Value | Description |
|----------|-------|-------------|
| `DEPLOY_PROVIDER` | `vercel` / `netlify` / `cloudflare` / `fly` / `custom` | Which provider to use |
| `DEPLOY_PROJECT_ID` | *(provider-specific)* | Project/site identifier |
| `DEPLOY_MODE` | `scripts` | Deploy mode |

#### 2. Set GitHub secrets

In your repo Settings > Secrets and variables > Actions > Secrets:

| Secret | Description |
|--------|-------------|
| `DEPLOY_TOKEN` | Provider authentication token |

#### 3. Build step

If your project needs a build step before deploy (e.g., `npm run build`),
ensure the setup steps in `.github/workflows/pr-deploy.yml` and
`.github/workflows/deploy-production.yml` are configured for your stack.

### Native mode setup

#### Vercel

1. Install CLI: `npm i -g vercel`
2. Link repo: `vercel link`
3. Vercel auto-detects pushes to `main` (production) and PR branches (previews)
4. Config: `vercel.json` — edit `buildCommand` and `outputDirectory` for your stack

#### Netlify

1. Install CLI: `npm i -g netlify-cli`
2. Link repo: `netlify init`
3. Netlify auto-detects pushes to `main` (production) and PR branches (previews)
4. Config: `netlify.toml` — edit `command` and `publish` for your stack

#### Cloudflare Pages

1. Install CLI: `npm i -g wrangler`
2. Create project: `wrangler pages project create <name> --production-branch main`
3. Connect your GitHub repo in the Cloudflare dashboard
4. Config: `wrangler.toml` — edit `pages_build_output_dir` for your stack

#### Fly.io

> **Note:** Fly.io has limited native Git integration. Only production deploys on
> `main` are automatic via Fly's GitHub app. PR preview deploys are **not available**
> in native mode. Use GitHub Actions (scripts mode) if you need PR previews.

1. Install CLI: `curl -L https://fly.io/install.sh | sh`
2. Launch app: `fly launch --no-deploy`
3. Connect GitHub in the Fly dashboard for automatic deploys on `main`
4. Store `FLY_API_TOKEN` as a GitHub secret

## Provider-specific notes (scripts mode)

### Vercel

```bash
# pr-preview.sh runs:
vercel deploy --token "$DEPLOY_TOKEN" --yes
```

Requires: `DEPLOY_TOKEN` = Vercel token from vercel.com/account/tokens

### Netlify

```bash
# pr-preview.sh runs:
netlify deploy --dir="$BUILD_DIR" --auth "$DEPLOY_TOKEN" \
  --site "$DEPLOY_PROJECT_ID" --alias "pr-${PR_NUMBER}" --json
```

Requires: `DEPLOY_TOKEN` = Netlify PAT, `DEPLOY_PROJECT_ID` = site ID

### Cloudflare Pages

```bash
# pr-preview.sh runs:
wrangler pages deploy "$BUILD_DIR" \
  --project-name "$DEPLOY_PROJECT_ID" --branch "pr-${PR_NUMBER}"
```

Requires: `DEPLOY_TOKEN` = CF API token, `DEPLOY_PROJECT_ID` = project name

### Fly.io

```bash
# pr-preview.sh runs:
fly deploy --app "${DEPLOY_PROJECT_ID}-pr-${PR_NUMBER}" --remote-only
```

Requires: `DEPLOY_TOKEN` = Fly auth token, `DEPLOY_PROJECT_ID` = app name

### Custom

Edit both `pr-preview.sh` and `pr-cleanup.sh` directly.
The only contract: write the preview URL to `.deploy-artifacts/preview-url.txt`.
