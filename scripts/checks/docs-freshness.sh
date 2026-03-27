#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0

echo "Checking documentation freshness..."

# ── Required docs must exist ─────────────────────────
REQUIRED_DOCS=(
  "CLAUDE.md"
)

for doc in "${REQUIRED_DOCS[@]}"; do
  if [ ! -f "$ROOT_DIR/$doc" ]; then
    echo "  ERROR: [docs] Missing required doc: $doc"
    echo "    Remediation: Create $doc following the template in docs/"
    FAILED=1
  fi
done

# ── Check for broken internal links in markdown ──────
if command -v grep &>/dev/null; then
  # Find markdown links pointing to local files that don't exist
  while IFS= read -r md_file; do
    while IFS= read -r link; do
      # Extract path from markdown link syntax [text](path)
      path=$(echo "$link" | sed -n 's/.*](\([^)#]*\).*/\1/p')
      # Skip URLs and empty paths
      [ -z "$path" ] && continue
      echo "$path" | grep -q "^http" && continue
      # Resolve relative to the markdown file's directory
      dir=$(dirname "$md_file")
      resolved="$dir/$path"
      if [ ! -e "$resolved" ]; then
        echo "  WARN: [docs] Broken link in $(basename "$md_file"): $path"
      fi
    done < <(grep -v '^\s*<!--' "$md_file" 2>/dev/null | grep -oE '\[([^]]*)\]\(([^)]*)\)' 2>/dev/null || true)
  done < <(find "$ROOT_DIR/docs" "$ROOT_DIR" -maxdepth 1 -name "*.md" 2>/dev/null)
fi

if [ "$FAILED" -ne 0 ]; then
  echo "Documentation freshness check failed."
  exit 1
else
  echo "Documentation freshness check passed."
fi
