#!/usr/bin/env python3
"""PreToolUse guard for Bash commands.

Reads a Claude Code hook payload on stdin and blocks destructive commands.
Exit code 2 with a stderr message blocks the tool call and surfaces the
message back to Claude.
"""

import json
import re
import sys

HARD_BLOCKS = [
    (r"\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\b",
     "rm -rf is blocked. Paths can be mistyped or unexpanded; use a safer delete "
     "or ask the user to confirm the exact target first."),

    (r"\bgit\s+reset\s+--hard\b",
     "git reset --hard is blocked. It discards uncommitted work irreversibly. "
     "Prefer git stash, git restore, or a new branch."),

    (r"\bgit\s+push\s+(-f|--force\b|--force-with-lease\b)",
     "Force push is blocked. It can overwrite upstream history. Rebase on top "
     "of origin and push normally, or ask the user before forcing."),

    (r"\bgit\s+clean\s+-[a-zA-Z]*f",
     "git clean -f is blocked. It permanently deletes untracked files. "
     "Review git status first and remove files individually."),

    (r"(?:^|[;&|])\s*sudo\b",
     "sudo is blocked. Claude should not escalate privileges autonomously."),

    (r"\bchmod\s+(-[a-zA-Z]*R[a-zA-Z]*\s+)?777\b",
     "chmod 777 is blocked. World-writable permissions are almost never right; "
     "use a specific mode like 755 or 644."),

    (r"\bcurl\b[^|]*\|\s*(sh|bash|zsh|python|python3)\b",
     "Piping curl directly to a shell is blocked. Download the script, inspect "
     "it, then run it explicitly."),

    (r"\bwget\b[^|]*\|\s*(sh|bash|zsh|python|python3)\b",
     "Piping wget directly to a shell is blocked. Download the script, inspect "
     "it, then run it explicitly."),

    (r"\bDROP\s+TABLE\b",
     "DROP TABLE is blocked. Destructive schema changes need explicit user "
     "confirmation — ask before running."),

    (r"\bTRUNCATE\s+(TABLE\s+)?\w+",
     "TRUNCATE is blocked. It wipes table contents irreversibly — ask before "
     "running."),

    (r"\bDELETE\s+FROM\s+\w+\s*(;|$)",
     "Unbounded DELETE FROM is blocked. Add a WHERE clause or confirm with the "
     "user that you intend to wipe the entire table."),
]


QUOTED_STRING = re.compile(
    r"'(?:[^'\\]|\\.)*'"
    r"|\"(?:[^\"\\]|\\.)*\""
)


def strip_quoted(command: str) -> str:
    """Replace the contents of quoted strings with placeholders so regex
    checks don't fire on string literals (e.g. `echo 'rm -rf ...'`)."""
    return QUOTED_STRING.sub("\"\"", command)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    tool_input = payload.get("tool_input") or {}
    command = tool_input.get("command", "")
    if not command:
        return 0

    scrubbed = strip_quoted(command)

    for pattern, message in HARD_BLOCKS:
        if re.search(pattern, scrubbed, re.IGNORECASE):
            print(f"BLOCKED: {message}", file=sys.stderr)
            return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
