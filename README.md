# claude-code-status-line

A Claude Code status line script that shows your real-time usage against the 5-hour and 7-day rate limits, with color-coded bars and a countdown to the next reset.

<img width="584" height="165" alt="image" src="https://github.com/user-attachments/assets/1c61002b-37c6-4e99-bbcf-67a61fc93053" />

- Green bar: under 50% used
- Yellow bar: 50–79%
- Red bar: 80%+
- `↻` shows time until the window resets

## Requirements

- [Claude Code](https://claude.ai/code) with an active subscription (OAuth credentials)
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
       "command": "~/.local/bin/claude-code-usage-status-line.py ~/.claude",
       "refreshInterval": 60
     }
   }
   ```

   Replace `~/.claude` with the actual config directory for that profile.

3. Restart Claude Code.

## How it works

- On each refresh, the script reads `<config_dir>/.credentials.json` for the OAuth access token (this file is written by Claude Code on Linux; macOS stores credentials in the keychain instead — see below)
- It calls `https://api.anthropic.com/api/oauth/usage` with the `anthropic-beta: oauth-2025-04-20` header
- Results are cached in `/tmp/claude-usage-<hash>.txt` for 58 seconds to avoid hammering the API (Claude Code refreshes every 60s)
- If the credentials file is missing or the token is absent, the script exits silently — safe to configure on profiles not yet logged in

## Platform notes

**Linux:** credentials are stored in `~/.claude/.credentials.json` (or the equivalent config dir).

**macOS:** credentials are stored in the keychain under the service name `Claude Code-credentials`. The script reads them via `security find-generic-password -s 'Claude Code-credentials' -w` and falls back to `.credentials.json` if the keychain lookup fails. Note that macOS stores one token for all profiles, so the config-dir argument only affects caching — the usage data shown will be the same across profiles.

## Development

Tests use [bats-core](https://github.com/bats-core/bats-core). Install it, then:

```bash
bats tests/
```

Tests install into `./tmp/` (gitignored) using explicit `--bin-dir` and config dir arguments so they never touch your real `~/.claude*` profiles.

## License

MIT
