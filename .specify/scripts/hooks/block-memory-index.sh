#!/usr/bin/env bash
# PreToolUse hook: block edits to .specify/memory/.index/ (gitignored LanceDB cache).
# Path match is anchored to this repo's root (CLAUDE_PROJECT_DIR when set,
# falling back to the resolved project root derived from this script's location)
# or to the repo-relative prefix, so the hook does not fire for other repos'
# index dirs in out-of-tree deployments (see LOG-057 MEMORY_REPO_ROOT).
# Receives hook event JSON on stdin; exits 2 to deny the tool call.
set -euo pipefail

FILE=$(jq -r '.tool_input.file_path // empty')
[[ -z "$FILE" ]] && exit 0

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
REL_PREFIX=".specify/memory/.index/"
ABS_PREFIX="${PROJECT_ROOT%/}/${REL_PREFIX}"

if [[ "$FILE" == "$ABS_PREFIX"* ]] || [[ "$FILE" == "$REL_PREFIX"* ]]; then
  echo "Blocked: .specify/memory/.index/ is a gitignored volatile cache managed by memory_sync. Edit source files in .specify/memory/ instead, then call mcp__memory__memory_sync." >&2
  exit 2
fi
exit 0
