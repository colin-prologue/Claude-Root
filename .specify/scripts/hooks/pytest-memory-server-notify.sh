#!/usr/bin/env bash
# PostToolUse hook: NOTIFY-ONLY pytest run after Python edits in memory-server/.
# By design this never gates the tool call — exit is always 0 and pytest output
# is prefixed so the reader knows it's informational. To promote to a real gate,
# drop `|| true`, add `set -e`, and remove the trailing `exit 0`.
set -uo pipefail

FILE=$(jq -r '.tool_input.file_path // empty')
if [[ "$FILE" == *memory-server/*.py ]]; then
  cd "$(dirname "$0")/../../.." || exit 0
  {
    echo "[pytest-notify] memory-server tests (non-blocking, tail -20):"
    (cd memory-server && uv run pytest -m 'not integration' -x -q 2>&1 | tail -20) || true
  } >&2
fi
exit 0
