#!/usr/bin/env python3
"""Stop hook that detects runaway repetition in the transcript.

Claude Code writes each tool call as a line-delimited JSON event in the
transcript file referenced by `transcript_path`. This hook scans the tail
of the transcript for the same Bash command repeating without progress,
or the same file being edited >15 times with no git commit.

It injects a message back into the session instead of blocking the stop,
so the agent gets a chance to break out of a loop. To hard-block stopping,
change the exit code to 2.
"""

import json
import re
import sys
from collections import Counter
from pathlib import Path

TAIL_EVENTS = 40
REPEAT_THRESHOLD = 5
EDIT_WITHOUT_COMMIT_THRESHOLD = 15


def load_events(path: Path):
    try:
        with path.open("r", encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
    except OSError:
        return []
    events = []
    for line in lines[-TAIL_EVENTS * 4 :]:
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except (json.JSONDecodeError, ValueError):
            continue
    return events


def extract_tool_calls(events):
    calls = []
    for event in events:
        tool = event.get("tool_name") or event.get("name")
        if not tool:
            continue
        tool_input = event.get("tool_input") or event.get("input") or {}
        calls.append((tool, tool_input))
    return calls


def check_repetition(calls):
    recent = calls[-TAIL_EVENTS:]
    bash_signatures = [
        (tool, inp.get("command", "").strip()[:120])
        for tool, inp in recent
        if tool == "Bash" and isinstance(inp, dict)
    ]
    counts = Counter(bash_signatures)
    for (tool, cmd), count in counts.items():
        if count >= REPEAT_THRESHOLD and cmd:
            return (
                f"Repetition detected: '{cmd[:80]}...' ran {count} times recently. "
                "Step back and reassess before continuing — either the approach "
                "is wrong or you're missing information."
            )
    return None


def check_edit_churn(calls):
    last_commit_idx = -1
    edit_files = []
    for i, (tool, inp) in enumerate(calls):
        if tool == "Bash" and isinstance(inp, dict):
            cmd = inp.get("command", "")
            if re.search(r"\bgit\s+commit\b", cmd):
                last_commit_idx = i
        if tool in {"Edit", "Write", "MultiEdit"} and isinstance(inp, dict):
            path = inp.get("file_path") or inp.get("notebook_path")
            if path:
                edit_files.append((i, path))

    edits_since_commit = [f for i, f in edit_files if i > last_commit_idx]
    if len(edits_since_commit) >= EDIT_WITHOUT_COMMIT_THRESHOLD:
        return (
            f"{len(edits_since_commit)} file edits since the last git commit. "
            "Consider committing a checkpoint before continuing so work is "
            "recoverable."
        )
    return None


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    transcript_path = payload.get("transcript_path")
    if not transcript_path:
        return 0

    events = load_events(Path(transcript_path))
    if not events:
        return 0

    calls = extract_tool_calls(events)
    messages = []
    for check in (check_repetition, check_edit_churn):
        msg = check(calls)
        if msg:
            messages.append(msg)

    if messages:
        print("\n\n".join(messages), file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
