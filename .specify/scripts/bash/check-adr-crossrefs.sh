#!/usr/bin/env bash
# Report ADR/LOG files in .specify/memory/ that have zero inbound references
# from any file under specs/.
#
# Principle VII (Decision Transparency, NON-NEGOTIABLE) mandates cross-references
# between decision records and spec/plan artifacts. This script checks the
# memory-to-specs direction only (outbound from memory). Missing inbound links
# are reported; reverse-direction checks (specs with no ADR refs) are out of scope.
set -euo pipefail

MEMORY_DIR=".specify/memory"
SPECS_DIR="specs"

if [[ ! -d "$MEMORY_DIR" ]] || [[ ! -d "$SPECS_DIR" ]]; then
  echo "error: expected $MEMORY_DIR and $SPECS_DIR to exist" >&2
  exit 1
fi

missing=()
checked=0

for f in "$MEMORY_DIR"/ADR_*.md "$MEMORY_DIR"/LOG_*.md; do
  [[ -e "$f" ]] || continue
  checked=$((checked + 1))
  base=$(basename "$f" .md)
  key=$(echo "$base" | grep -oE '^(ADR|LOG)_[0-9]+')
  dashed=${key/_/-}
  # Word-boundary anchors avoid false matches:
  #   - ADR_055 inside ADR_1055 (dormant until 4-digit IDs exist)
  #   - ADR_055 inside an unrelated substring like 123ADR_055abc (live today)
  if ! grep -rqE "(^|[^A-Za-z0-9_])(${key}|${dashed})([^0-9]|$)" "$SPECS_DIR" 2>/dev/null; then
    missing+=("$base")
  fi
done

echo "Checked: $checked decision records in $MEMORY_DIR"
if [[ ${#missing[@]} -eq 0 ]]; then
  echo "OK: all records have at least one reference from $SPECS_DIR/"
  exit 0
fi

echo "Missing inbound references (${#missing[@]}):"
for m in "${missing[@]}"; do
  echo "  - $m"
done
exit 2
