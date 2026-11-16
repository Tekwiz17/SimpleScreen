# Connect AI usage

SimpleScreen shows recorded provider rate-limit snapshots, **not** token-budget estimates and not credentials-derived requests.

## Codex

In Connections, enable **Read local Codex usage snapshots**, then add an AI Usage widget and select Codex.

The app checks JSONL files under `~/.codex/sessions`, looks for `payload.rate_limits`, and reads `primary` / `secondary` windows: `used_percent`, `window_minutes`, and `resets_at`. It takes the event timestamp when present. It does not assume primary means five hours: weekly-only windows are supported.

Scanning is capped at 30,000 directory entries, the 12 most recently modified JSONL files, and the last 2 MB of each. Very large/older archives can therefore be omitted. The format is an upstream implementation detail and may change.

A new Codex turn must record a limit event before new data appears. The widget refreshes every minute or on click. It never opens `auth.json` or sends session data anywhere.

Upstream: https://github.com/openai/codex/blob/main/codex-rs/tui/src/status/rate_limits.rs

## Claude Code

Recent Claude Code versions expose `rate_limits.five_hour` and `rate_limits.seven_day` in their status-line JSON. Availability depends on your version, account, and whether a response has populated those fields. Missing data stays unavailable.

1. Copy `tools/claude-statusline.py` from this repository to `~/.claude/simplescreen-statusline.py`.
2. Ensure Python 3 is installed.
3. Configure the command below in your existing `~/.claude/settings.json`, merging this key while preserving other settings:

```json
{
  "statusLine": {
    "type": "command",
    "command": "python3 \"$HOME/.claude/simplescreen-statusline.py\""
  }
}
```

**This replaces your status-line command.** If you already have a custom status line, integrate the helper into it instead, passing a copy of the same stdin JSON and discarding this helper's stdout. SimpleScreen does not edit Claude configuration automatically.

4. In SimpleScreen → Connections → Claude Code, click **Use default snapshot path**.
5. Add an AI Usage widget and select Claude Code. Run a Claude Code turn.

The helper saves only the two usage windows to `~/Library/Application Support/SimpleScreen/claude-usage.json`. Writes are atomic and owner-only. Transcript paths, prompts, session IDs, model data, and credentials are not saved. The terminal status line displays remaining percentages.

Official status-line documentation: https://code.claude.com/docs/en/statusline

## Reading the widget

Percent left = 100 − the provider's recorded used percentage. The reset time is the recorded provider time. SimpleScreen does not optimistically reset to 100% when that time passes. It labels the passed reset and waits for fresh data. An orange dot indicates a snapshot older than 15 minutes.

If there is no reading, enable the connection and run the relevant CLI. Unsupported/missing fields, missing files, invalid JSON, or invalid percentages display an unavailable state instead of invented usage.
