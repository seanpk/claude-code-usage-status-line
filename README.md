# claude-code-status-line

A Claude Code status line script showing current working directory, model, effort level, rate-limit usage bars, context window percentage, and cache hit rate — all in one line.

<img width="584" height="165" alt="image" src="https://github.com/user-attachments/assets/1c61002b-37c6-4e99-bbcf-67a61fc93053" />

```
my-project | Sonnet [high] | 5h ████░░░░░░  42% ↻47m  7d ██░░░░░░░░  18% ↻2d | ctx ██░░░░░░░░  17%  cache  71%
```

**Rate limit bars** (green <50%, yellow 50–79%, red 80%+) — `↻` shows time until window resets

**Context bar** — same color scale

**Cache hit rate** — inverse scale (green ≥70%, yellow 30–69%, red <30%); omitted before the first API call in a session

## Requirements

- [Claude Code](https://claude.ai/code) with an active subscription (Pro or Max)
- Python 3.6+
- Linux or macOS

## Quick install

```bash
git clone https://github.com/seanpk/claude-code-usage-status-line.git
cd claude-code-usage-status-line
./install.sh
```

The installer:

1. Copies `claude-code-usage-status-line.py` to `~/bin/` (falls back to `~/.local/bin` if `~/bin` doesn't exist; use `--bin-dir` to override)
2. Auto-detects Claude config directories (`~/.claude`, `~/.claude-*`) and writes the `statusLine` config into each `settings.json`
3. Restart Claude Code to activate

### Specifying an install location

```bash
./install.sh --bin-dir ~/.local/bin
# short form:
./install.sh -d ~/.local/bin
```

The script will warn you if the chosen directory is not on your `PATH`.

### Multiple profiles

If you run multiple Claude Code profiles (e.g. separate configs for different accounts), pass the config dirs explicitly:

```bash
./install.sh ~/.claude ~/.claude-home ~/.claude-work
```

You can combine both options:

```bash
./install.sh --bin-dir ~/.local/bin ~/.claude ~/.claude-home ~/.claude-work
```

## Uninstall

```bash
./uninstall.sh
```

This removes the script from `~/bin/` (or `~/.local/bin/`, or wherever `--bin-dir` points) and clears the `statusLine` key from every auto-detected Claude profile. Pass explicit config dirs to limit which profiles are touched:

```bash
./uninstall.sh ~/.claude ~/.claude-work
```

## Manual install

1. Copy `claude-code-usage-status-line.py` to a directory on your `PATH` and make it executable:

   ```bash
   cp claude-code-usage-status-line.py ~/.local/bin/
   chmod +x ~/.local/bin/claude-code-usage-status-line.py
   ```

2. Add the following to each Claude Code `settings.json` you want to configure (e.g. `~/.claude/settings.json`):

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.local/bin/claude-code-usage-status-line.py",
       "refreshInterval": 60
     }
   }
   ```

3. Restart Claude Code.

## How it works

Claude Code sends a JSON object to the script via stdin on every update (after each assistant message, after `/compact`, and on a 60-second timer). The script reads that data and prints the formatted status line — no credentials, no API calls, no cache files needed.

Fields used from the session JSON:

| Field | Used for |
|-------|----------|
| `workspace.current_dir` | cwd section |
| `model.display_name` | model section |
| `effort.level` | effort tag (omitted when absent) |
| `rate_limits.five_hour / seven_day` | usage bars + reset countdown |
| `context_window.used_percentage` | context bar |
| `context_window.current_usage` | cache hit rate |

The `rate_limits` field is only present for Pro/Max subscribers after the first API response in a session; the section is omitted silently when absent.

## Platform notes

**Linux and macOS:** the script works identically — all data comes from Claude Code via stdin, so no credential reading or keychain access is needed.

**Windows:** not currently supported (the script uses a Unix shebang and is not tested on Windows).

## Development

Tests use [bats-core](https://github.com/bats-core/bats-core). Install it, then:

```bash
bats tests/
```

Tests install into `./tmp/` (gitignored) using explicit `--bin-dir` and config dir arguments so they never touch your real `~/.claude*` profiles. `tests/script.bats` tests the Python script directly by piping mock JSON via stdin.

## License

MIT
