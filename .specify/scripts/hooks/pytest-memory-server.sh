#!/usr/bin/env bash
# PostToolUse hook: run memory-server unit/contract tests after Python edits there.
# Non-blocking; exits 0 regardless of test outcome but surfaces failures via stderr.
set -uo pipefail

FILE=$(jq -r '.tool_input.file_path // empty')
if [[ "$FILE" == *memory-server/*.py ]]; then
  cd "$(dirname "$0")/../../.." || exit 0
  (cd memory-server && uv run pytest -m 'not integration' -x -q 2>&1 | tail -20) >&2 || true
fi
exit 0
