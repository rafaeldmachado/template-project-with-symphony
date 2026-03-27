---
tracker:
  kind: github
  repo: test-owner/test-repo
  project_number: 42
  active_states:
    - ready
    - in-progress
  terminal_states:
    - done
    - closed
    - cancelled

polling:
  interval_ms: 600000

workspace:
  root: .test-worktrees

hooks:
  after_create: |
    git checkout -b "issue/${ISSUE_NUMBER}"
    make setup
  before_run: |
    git pull --rebase origin main
  after_run: |
    make check

agent:
  name: claude
  model: opus
  max_turns: 100
  max_budget_usd: 25
  max_concurrent_agents: 3
  max_retry_backoff_ms: 600000
  turn_timeout_ms: 7200000
---

You are working on issue **#{{ issue.identifier }}**: *{{ issue.title }}*

{{ issue.description }}

{% if issue.labels.size > 0 %}
**Labels:** {{ issue.labels | join: ", " }}
{% endif %}

{% if issue.blocked_by.size > 0 %}
**Blocked by:**
{% for blocker in issue.blocked_by %}
- {{ blocker.identifier }} ({{ blocker.state }})
{% endfor %}
{% endif %}

{% if attempt %}
**Retry attempt {{ attempt }}.**
{% endif %}
