#!/usr/bin/env bash
# PreToolUse hook: block edits to .specify/memory/.index/ (gitignored LanceDB cache).
# Receives hook event JSON on stdin; exits 2 to deny the tool call.
set -euo pipefail

FILE=$(jq -r '.tool_input.file_path // empty')
if [[ "$FILE" == *.specify/memory/.index/* ]]; then
  echo "Blocked: .specify/memory/.index/ is a gitignored volatile cache managed by memory_sync. Edit source files in .specify/memory/ instead, then call mcp__memory__memory_sync." >&2
  exit 2
fi
exit 0
