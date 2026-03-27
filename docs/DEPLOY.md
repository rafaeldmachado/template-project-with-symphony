# Deploy Configuration

Ephemeral PR preview deploys give humans a live environment to validate
agent work before merging. This is a critical feedback loop — it lets you
verify behavior without checking out the branch locally.

## How it works

1. Agent opens a PR
2. `pr-deploy.yml` workflow triggers and runs `scripts/deploy/pr-preview.sh`
3. The script deploys to your provider and writes the URL to `.deploy-artifacts/preview-url.txt`
4. The workflow comments the preview URL on the PR
5. When the PR is closed/merged, `pr-cleanup.yml` tears it down

## Setup

### 1. Choose a provider

Set the `DEPLOY_PROVIDER` variable in GitHub (Settings > Secrets and variables > Actions > Variables):

| Provider | Value | Best for |
|----------|-------|----------|
| Vercel | `vercel` | Frontend apps, Next.js |
| Netlify | `netlify` | Static sites, Jamstack |
| Cloudflare Pages | `cloudflare` | Static/SSR with edge |
| Fly.io | `fly` | Full-stack, Docker apps |
| Custom | `custom` | Anything else |

### 2. Add secrets

Add the `DEPLOY_TOKEN` secret and optionally `DEPLOY_PROJECT_ID` variable,
depending on your provider.

### 3. Configure the deploy script

Edit `scripts/deploy/pr-preview.sh` and uncomment the block for your provider.
Each block has a comment showing the required command and env vars.

Do the same for `scripts/deploy/pr-cleanup.sh`.

### 4. Build step

If your project needs a build step before deploy (e.g., `npm run build`),
uncomment the setup steps in `.github/workflows/pr-deploy.yml` (after `make init`).

## Provider-specific notes

### Vercel

```bash
# In pr-preview.sh, the vercel block:
PREVIEW_URL=$(npx vercel --token "$DEPLOY_TOKEN" --yes 2>&1 | tail -1)
echo "$PREVIEW_URL" > "$URL_FILE"
```

Requires: `DEPLOY_TOKEN` = Vercel token from vercel.com/account/tokens

### Netlify

```bash
# In pr-preview.sh, the netlify block:
PREVIEW_URL=$(npx netlify deploy --alias "pr-${PR_NUMBER}" \
  --auth "$DEPLOY_TOKEN" --site "$DEPLOY_PROJECT_ID" \
  --json | jq -r '.deploy_url')
echo "$PREVIEW_URL" > "$URL_FILE"
```

Requires: `DEPLOY_TOKEN` = Netlify PAT, `DEPLOY_PROJECT_ID` = site ID

### Cloudflare Pages

```bash
# In pr-preview.sh, the cloudflare block:
npx wrangler pages deploy dist \
  --project-name "$DEPLOY_PROJECT_ID" \
  --branch "pr-${PR_NUMBER}"
echo "https://pr-${PR_NUMBER}.$DEPLOY_PROJECT_ID.pages.dev" > "$URL_FILE"
```

Requires: `DEPLOY_TOKEN` = CF API token, `DEPLOY_PROJECT_ID` = project name

### Fly.io

```bash
# In pr-preview.sh, the fly block:
fly deploy --app "your-project-pr-${PR_NUMBER}" --remote-only
echo "https://your-project-pr-${PR_NUMBER}.fly.dev" > "$URL_FILE"
```

Requires: `DEPLOY_TOKEN` = Fly auth token

### Custom

Edit both `pr-preview.sh` and `pr-cleanup.sh` directly.
The only contract: write the preview URL to `.deploy-artifacts/preview-url.txt`.
