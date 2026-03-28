# Setup Guide

How to configure this template for a new project.

## Quick start (wizard)

```bash
git clone <this-repo-url> my-project
cd my-project
make init
```

The wizard walks you through choosing your stack, configuring GitHub, deploys,
AI agent, and monitoring. It scaffolds the project, writes config files,
creates labels, sets up a project board with status columns, configures
repository permissions, and stores secrets — all automatically.

After the wizard, run `make setup` to install dependencies, then `make check` to verify.

## Manual setup

If you prefer to configure things by hand, follow the steps below.

### 1. Clone and initialize

```bash
git clone <this-repo-url> my-project
cd my-project
mv _github .github    # activate GitHub config (workflows, templates)
make setup
```

The template stores GitHub config in `_github/` (without the dot) so workflows don't
trigger on the template repo. Move it to `.github/` before doing anything else.
(`make init` does this automatically.)

`make setup` makes scripts executable and creates working directories.

## 2. Choose your stack

The template is framework-agnostic. Wire in your language and tools:

| File | What to configure |
|------|-------------------|
| `scripts/checks/lint.sh` | Uncomment/add your linter |
| `scripts/checks/test.sh` | Uncomment/add your test runner |
| `.github/workflows/ci.yml` | Uncomment the setup step for your runtime (after `make init`) |
| `.github/workflows/symphony.yml` | Uncomment the setup step + one agent block (after `make init`) |

## 3. Configure GitHub

> **Note:** `make init` handles all of the below automatically — repository settings,
> secrets, variables, project board, and labels. These manual steps are only needed
> if you skipped the GitHub step during the wizard.

### Repository settings

1. Go to **Settings > General > Features** and enable Issues and Projects.

2. Go to **Settings > Actions > General**:
   - Allow all actions
   - Set workflow permissions to "Read and write permissions"
   - Check "Allow GitHub Actions to create and approve pull requests"

### Secrets and variables

Go to **Settings > Secrets and variables > Actions**:

**Secrets** (sensitive values):

| Name | Required for | Value |
|------|-------------|-------|
| `PROJECT_TOKEN` | Project board sync | A PAT with `project` scope (auto-set by wizard) |
| `DEPLOY_TOKEN` | PR preview deploys | Your deploy provider token |
| `ANTHROPIC_API_KEY` | Symphony (Claude, API key) | Your Anthropic Console API key |
| `CLAUDE_CODE_OAUTH_TOKEN` | Symphony (Claude, OAuth) | Token from `claude setup-token` (Max/Teams/Enterprise) |
| `OPENAI_API_KEY` | Symphony (Codex) | Your OpenAI API key |

Only add the secrets you need. Symphony needs exactly one agent key.
For Claude Code, choose either `ANTHROPIC_API_KEY` (Console API) or
`CLAUDE_CODE_OAUTH_TOKEN` (Max/Teams/Enterprise subscription) — not both.

**Variables** (non-sensitive):

| Name | Required for | Value |
|------|-------------|-------|
| `PROJECT_URL` | Project board sync | Full project URL (e.g. `https://github.com/users/you/projects/3`) |
| `PROJECT_NUMBER` | Project board sync | The number from your project URL |
| `DEPLOY_PROVIDER` | PR preview deploys | `vercel`, `netlify`, `cloudflare`, `fly`, or `custom` |
| `DEPLOY_PROJECT_ID` | PR preview deploys | Your deploy project/site ID |

### GitHub Project board

> The wizard creates the project board automatically with Status columns
> (`Backlog`, `Ready`, `In Progress`, `Under Review`, `Done`), sets
> `PROJECT_URL` and `PROJECT_NUMBER` as repo variables, and stores
> `PROJECT_TOKEN` as a repo secret.

If setting up manually:

1. Go to your org or user's Projects tab and create a new project.
2. Add Status columns: `Backlog`, `Ready`, `In Progress`, `Under Review`, `Done`.
3. Note the project number from the URL (e.g., `github.com/orgs/acme/projects/3` → `3`).
4. Add `PROJECT_URL` (full URL) and `PROJECT_NUMBER` as repo variables.
5. Create a PAT at github.com/settings/tokens with `project` scope and add it
   as the `PROJECT_TOKEN` secret.

### Labels

> The wizard creates all required labels automatically.

If setting up manually, create these labels (Settings > Labels):

| Label | Color | Purpose |
|-------|-------|---------|
| `ready` | `#0E8A16` | Issue is ready for agent work |
| `agent` | `#5319E7` | Issue should be handled by an AI agent |
| `in-progress` | `#FBCA04` | Agent is working on it (set by Symphony) |
| `human-review` | `#0075CA` | PR created, needs human review (set by Symphony) |
| `p0` | `#B60205` | Critical priority (dispatched first) |
| `p1` | `#D93F0B` | High priority |
| `p2` | `#FBCA04` | Normal priority |
| `bug` | `#D73A4A` | Bug report |
| `enhancement` | `#A2EEEF` | Feature request |
| `story` | `#C5DEF5` | User story |

The first four are used by the Symphony workflow. Issues need both `ready` + `agent`
to be picked up for autonomous work. Priority labels (`p0` > `p1` > `p2`) control
dispatch order — issues without a priority label are dispatched last.

## 4. Configure deploys (optional)

See [DEPLOY.md](DEPLOY.md) for ephemeral PR preview setup.

## 5. Self-hosted runner (optional)

Use your own machine as a GitHub Actions runner to save CI minutes. When your machine
is offline, jobs automatically fall back to GitHub-hosted runners (`ubuntu-latest`).

### Quick setup (via wizard)

The `make init` wizard offers this as step 7. If you skipped it, run:

```bash
make setup-runner
```

This downloads the GitHub Actions runner, registers it with your repo, and installs it
as a background service.

### How it works

The runner **polls GitHub outbound over HTTPS** (port 443). No inbound ports, SSH, firewall
rules, or static IP needed. It works behind NAT, corporate firewalls, and VPNs.

The CI and Symphony workflows include a `pick-runner` job that checks whether a self-hosted
runner is online. If one is available, the work runs there (free). If not, it falls back to
`ubuntu-latest` (uses GitHub Actions minutes).

### Supported platforms

| Platform | Service type                | Auto-start                              |
| -------- | --------------------------- | --------------------------------------- |
| macOS    | LaunchAgent                 | On login                                |
| Linux    | systemd user service        | On boot (with `loginctl enable-linger`) |
| Windows  | Windows Service             | On boot (requires admin install)        |

On Windows, use Git Bash, MSYS2, or WSL to run `make setup-runner`. The runner binary
and service are native Windows — only the setup script uses Bash.

### Managing the runner

```bash
make runner-status    # check if runner is online
make runner-start     # start the service
make runner-stop      # stop the service
make runner-remove    # unregister and delete
```

### Network requirements

The runner only needs **outbound HTTPS** to these hosts:

- `github.com`
- `api.github.com`
- `*.actions.githubusercontent.com`
- `*.blob.core.windows.net` (for caching)

If you're behind a corporate proxy, set the `HTTPS_PROXY` environment variable
before running `make setup-runner`.

## 6. Start building

### Manual mode (agent in your terminal)

```bash
make worktree ISSUE=1         # create isolated workspace
cd .worktrees/1
# ... work on the issue ...
make check                    # validate
git push -u origin issue/1    # push and open PR
```

### Autonomous mode (Symphony)

1. Set `agent.name` to `claude` or `codex` in `WORKFLOW.md`
2. Add the corresponding secret (`ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, or `OPENAI_API_KEY`) — the wizard does this automatically
3. Create an issue, add the `ready` + `agent` labels
4. Symphony picks it up on the next poll and delivers a PR

## 7. Define your architecture

As you build, fill in:

- `docs/DESIGN.md` — your domain map and system boundaries
- `docs/architecture/layers.md` — is already set up with the standard layers
- `docs/design-docs/` — add design docs for significant decisions
- `docs/product-specs/` — add product specifications

The structural tests in `tests/structural/` enforce the layer dependencies.
When your project has a `src/` directory, uncomment the layer validation
section in `tests/structural/architecture.sh`.
