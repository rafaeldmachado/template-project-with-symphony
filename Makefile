.PHONY: help init teardown setup check lint test test-e2e structure worktree worktree-cleanup \
       gc gc-branches gc-worktrees gc-deploys gc-artifacts \
       deploy-preview deploy-cleanup deploy-prod test-template \
       setup-runner runner-start runner-stop runner-status runner-remove

SHELL := /bin/bash
.DEFAULT_GOAL := help

# ──────────────────────────────────────────────
# Help
# ──────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ──────────────────────────────────────────────
# Setup
# ──────────────────────────────────────────────

init: ## Interactive wizard — configure stack, GitHub, deploys, agent
	@./scripts/init.sh

teardown: ## Undo init — remove runner, repo, config, git state
	@./scripts/teardown.sh

setup: ## Install dependencies and configure the project
	@./scripts/setup.sh

# ──────────────────────────────────────────────
# Checks (CI runs these)
# ──────────────────────────────────────────────

check: ## Run all checks (lint + structure + tests)
	@./scripts/checks/run-all.sh

lint: ## Run linters
	@./scripts/checks/lint.sh

test: ## Run unit and integration tests
	@./scripts/checks/test.sh

test-e2e: ## Run end-to-end tests
	@./scripts/checks/test.sh --e2e

structure: ## Run structural/architecture tests
	@./scripts/checks/structure.sh

# ──────────────────────────────────────────────
# Worktree management
# ──────────────────────────────────────────────

worktree: ## Create a worktree for an issue (usage: make worktree ISSUE=123)
ifndef ISSUE
	$(error ISSUE is required. Usage: make worktree ISSUE=123)
endif
	@./scripts/worktree/create.sh $(ISSUE)

worktree-cleanup: ## Clean up a worktree (usage: make worktree-cleanup ISSUE=123)
ifndef ISSUE
	$(error ISSUE is required. Usage: make worktree-cleanup ISSUE=123)
endif
	@./scripts/worktree/cleanup.sh $(ISSUE)

# ──────────────────────────────────────────────
# Garbage collection (DRY_RUN=false to execute)
# ──────────────────────────────────────────────

gc: ## Run all garbage collection (DRY_RUN=false to execute)
	@DRY_RUN=$${DRY_RUN:-false} ./scripts/gc/clean-branches.sh
	@DRY_RUN=$${DRY_RUN:-false} ./scripts/gc/clean-worktrees.sh
	@DRY_RUN=$${DRY_RUN:-false} ./scripts/gc/clean-deploys.sh
	@DRY_RUN=$${DRY_RUN:-false} ./scripts/gc/clean-artifacts.sh
	@echo "GC complete."

gc-branches: ## Clean merged and stale branches
	@DRY_RUN=$${DRY_RUN:-false} ./scripts/gc/clean-branches.sh

gc-worktrees: ## Clean abandoned worktrees
	@DRY_RUN=$${DRY_RUN:-false} ./scripts/gc/clean-worktrees.sh

gc-deploys: ## Clean orphaned PR deploys
	@DRY_RUN=$${DRY_RUN:-false} ./scripts/gc/clean-deploys.sh

gc-artifacts: ## Clean old CI artifacts
	@DRY_RUN=$${DRY_RUN:-false} ./scripts/gc/clean-artifacts.sh

# ──────────────────────────────────────────────
# Deploy
# ──────────────────────────────────────────────

deploy-preview: ## Deploy a PR preview (usage: make deploy-preview PR=123)
ifndef PR
	$(error PR is required. Usage: make deploy-preview PR=123)
endif
	@./scripts/deploy/pr-preview.sh $(PR)

deploy-cleanup: ## Tear down a PR preview (usage: make deploy-cleanup PR=123)
ifndef PR
	$(error PR is required. Usage: make deploy-cleanup PR=123)
endif
	@./scripts/deploy/pr-cleanup.sh $(PR)

deploy-prod: ## Deploy to production
	@./scripts/deploy/production.sh

# ──────────────────────────────────────────────
# Self-hosted runner
# ──────────────────────────────────────────────

setup-runner: ## Install and register a self-hosted GitHub Actions runner
	@./scripts/runner/setup.sh

runner-start: ## Start the self-hosted runner service
	@./scripts/runner/manage.sh start

runner-stop: ## Stop the self-hosted runner service
	@./scripts/runner/manage.sh stop

runner-status: ## Show self-hosted runner status
	@./scripts/runner/manage.sh status

runner-remove: ## Unregister and remove the self-hosted runner
	@./scripts/runner/manage.sh remove

# ──────────────────────────────────────────────
# Template tests (validates the template itself)
# ──────────────────────────────────────────────

test-template: ## Run template infrastructure tests
	@.github/template-tests/run.sh $(if $(SUITE),$(SUITE),all)
