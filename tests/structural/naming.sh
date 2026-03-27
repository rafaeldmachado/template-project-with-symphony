#!/usr/bin/env bash
set -euo pipefail

# Structural test: validate naming conventions.
#
# Enforces consistent naming patterns across the codebase
# to keep it legible for agents and humans alike.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0

echo "Validating naming conventions..."

# ── Scripts must be executable ───────────────────────
while IFS= read -r script; do
  if [ ! -x "$script" ]; then
    relpath="${script#"$ROOT_DIR"/}"
    echo "ERROR: [naming] Script not executable: $relpath"
    echo "  Remediation: Run 'chmod +x $relpath'"
    FAILED=1
  fi
done < <(find "$ROOT_DIR/scripts" -name "*.sh" -type f 2>/dev/null || true)

# ── Docs must use lowercase filenames with hyphens ───
while IFS= read -r doc; do
  filename=$(basename "$doc")
  # Skip well-known uppercase files
  case "$filename" in
    README.md|DESIGN.md|PLANS.md|QUALITY_SCORE.md|RELIABILITY.md|FRONTEND.md|PRODUCT_SENSE.md|SETUP.md|DEPLOY.md) continue ;;
  esac
  if echo "$filename" | grep -qE '[A-Z].*\.md$'; then
    relpath="${doc#"$ROOT_DIR"/}"
    echo "WARN: [naming] Doc uses uppercase: $relpath"
    echo "  Convention: Use lowercase-with-hyphens.md for docs in subdirectories."
  fi
done < <(find "$ROOT_DIR/docs" -name "*.md" -not -path "*/\.*" 2>/dev/null || true)

# ── No spaces in filenames ───────────────────────────
while IFS= read -r file; do
  filename=$(basename "$file")
  if echo "$filename" | grep -q ' '; then
    relpath="${file#"$ROOT_DIR"/}"
    echo "ERROR: [naming] Filename contains spaces: $relpath"
    echo "  Remediation: Use hyphens or underscores instead of spaces."
    FAILED=1
  fi
done < <(find "$ROOT_DIR/src" "$ROOT_DIR/scripts" "$ROOT_DIR/tests" -type f 2>/dev/null || true)

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi

echo "Naming conventions passed."
