# claude-code-status-line

A Claude Code status line script that shows your real-time usage against the 5-hour and 7-day rate limits, with color-coded bars and a countdown to the next reset.

```
5h ████████░░  80%  ↻47m    7d ████░░░░░░  42%  ↻2d
```

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
git clone https://github.com/seanpk/claude-code-status-line.git
cd claude-code-status-line
./install.sh
```

The installer:

1. Copies `claude-usage-status.py` to `~/bin/`
2. Auto-detects Claude config directories (`~/.claude`, `~/.claude-*`) and writes the `statusLine` config into each `settings.json`
3. Restart Claude Code to activate

### Multiple profiles

If you run multiple Claude Code profiles (e.g. separate configs for different accounts), pass the config dirs explicitly:

```bash
./install.sh ~/.claude ~/.claude-work ~/.claude-personal
```

## Manual install

1. Copy `claude-usage-status.py` to a directory on your `PATH` and make it executable:

   ```bash
   cp claude-usage-status.py ~/bin/
   chmod +x ~/bin/claude-usage-status.py
   ```

2. Add the following to each Claude Code `settings.json` you want to configure (e.g. `~/.claude/settings.json`):

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/bin/claude-usage-status.py ~/.claude",
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

**Linux:** credentials are stored in `~/.claude/.credentials.json` (or the equivalent config dir). This script works as-is.

**macOS:** Claude Code stores credentials in the macOS keychain, not a `.credentials.json` file, so this script will produce no output on macOS as written. A keychain-aware version would need to use the `security` CLI tool.

## License

MIT
