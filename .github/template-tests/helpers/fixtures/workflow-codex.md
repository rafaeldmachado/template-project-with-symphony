---
tracker:
  kind: github
agent:
  name: codex
  model: o3
  max_turns: 30
  max_budget_usd: 5
---

You are working on issue **#{{ issue.identifier }}**: *{{ issue.title }}*
