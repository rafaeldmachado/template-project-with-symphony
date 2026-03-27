# Security Policy

## Reporting a vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do not open a public issue.** Instead, contact the maintainers directly via email
or use GitHub's private vulnerability reporting feature (Security tab > Report a vulnerability).

We will acknowledge receipt within 48 hours and aim to provide a fix or mitigation
within 7 days for critical issues.

## Security practices in this template

This template enforces several security practices by design:

- **No secrets in code** — all credentials go through `.env` (gitignored) or GitHub
  Actions secrets. The structural tests scan for common secret patterns.
- **CI validation** — all changes go through PR review and automated checks.
  No manual hotfixes.
- **Dependency auditing** — the check pipeline includes dependency vulnerability
  scanning when configured for your stack.
- **Ephemeral environments** — PR preview deploys are automatically torn down
  when PRs close, limiting exposure of preview environments.
- **Agent permissions** — AI agents in CI run with scoped permissions. The
  `GITHUB_TOKEN` has only the permissions declared in the workflow file.

## What to report

- Vulnerabilities in the template scripts or workflows
- Cases where the template's security practices can be bypassed
- Issues with how secrets or credentials are handled
- CI/CD pipeline security concerns

## Out of scope

- Vulnerabilities in downstream projects built with this template (those are the
  responsibility of the project maintainers)
- Vulnerabilities in third-party tools (GitHub Actions, deploy providers, AI agents)
  — report those to the respective vendors
