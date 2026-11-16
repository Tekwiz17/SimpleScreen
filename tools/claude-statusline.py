#!/usr/bin/env python3
"""Opt-in Claude Code status-line bridge. Saves only usage fields, never the transcript."""
import json
import os
from pathlib import Path
import sys
import tempfile

def snapshot(payload):
    source = payload.get("rate_limits") if isinstance(payload, dict) else None
    if not isinstance(source, dict):
        return {"rate_limits": {}}
    result = {}
    for key in ("five_hour", "seven_day"):
        window = source.get(key)
        if not isinstance(window, dict):
            continue
        used = window.get("used_percentage")
        if isinstance(used, (int, float)) and not isinstance(used, bool) and 0 <= used <= 100:
            result[key] = {"used_percentage": used}
            reset = window.get("resets_at")
            if isinstance(reset, (int, float)) and not isinstance(reset, bool):
                result[key]["resets_at"] = reset
    return {"rate_limits": result}

def main():
    payload = json.load(sys.stdin)
    result = snapshot(payload)
    folder = Path.home() / "Library" / "Application Support" / "SimpleScreen"
    folder.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".claude-", suffix=".json", dir=folder)
    try:
        with os.fdopen(descriptor, "w") as handle:
            json.dump(result, handle)
        os.replace(temporary, folder / "claude-usage.json")
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    windows = result["rate_limits"]
    labels = [f"{'5h' if key == 'five_hour' else '7d'} {100-value['used_percentage']:.0f}% left" for key, value in windows.items()]
    print(" · ".join(labels) if labels else "Claude Code")

if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, TypeError):
        print("Claude Code")
