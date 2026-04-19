#!/usr/bin/env python3
"""PreToolUse guard for Edit/Write/MultiEdit.

Warns (does not block) on sensitive file edits and debug artifacts.
Exit code 0 always; warnings are printed to stderr so Claude sees them.
"""

import json
import re
import sys

SENSITIVE_PATH = re.compile(
    r"(?:^|[\\/])"
    r"(?:\.env(?:\.[\w.-]+)?|credentials|secrets|[^\\/]*\.pem|[^\\/]*\.key)$",
    re.IGNORECASE,
)

PYTHON_DEBUG = re.compile(
    r"(?m)^\s*(?:print\(|breakpoint\(\)|import\s+pdb|from\s+pdb\s+import)"
)

COMMIT_TO_MAIN = re.compile(
    r"\bgit\s+commit\b(?![^\n]*--amend)"
)


def warn(message: str) -> None:
    print(f"WARNING: {message}", file=sys.stderr)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path", "") or tool_input.get("notebook_path", "")
    new_text = (
        tool_input.get("new_string")
        or tool_input.get("content")
        or tool_input.get("new_source")
        or ""
    )

    if file_path and SENSITIVE_PATH.search(file_path):
        warn(
            f"Editing a sensitive file ({file_path}). Confirm it is gitignored "
            "and never hardcode credentials — use env vars or a secrets manager."
        )

    if file_path.endswith(".py") and PYTHON_DEBUG.search(new_text):
        warn(
            "Debug artifact detected (print/breakpoint/pdb). Remove before "
            "shipping; use the `logging` module for persistent output."
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
