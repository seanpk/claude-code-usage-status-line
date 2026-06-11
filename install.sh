#!/usr/bin/env bash
# Installs claude-usage-status.py and configures statusLine in Claude Code profiles.
#
# Usage:
#   ./install.sh                        # auto-detect profiles under ~/
#   ./install.sh ~/.claude ~/.claude-rm # configure specific profiles only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SRC="$SCRIPT_DIR/claude-usage-status.py"
INSTALL_DIR="${HOME}/bin"
INSTALL_PATH="$INSTALL_DIR/claude-usage-status.py"

# --- Install the script ---
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_SRC" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
echo "Installed: $INSTALL_PATH"

# --- Resolve which config dirs to configure ---
if [ $# -gt 0 ]; then
    mapfile -t CONFIG_DIRS < <(printf '%s\n' "$@")
else
    # Auto-detect: ~/.claude and any ~/.claude-* directories
    CONFIG_DIRS=()
    [ -d "$HOME/.claude" ] && CONFIG_DIRS+=("$HOME/.claude")
    for dir in "$HOME"/.claude-*; do
        [ -d "$dir" ] && CONFIG_DIRS+=("$dir")
    done
fi

if [ ${#CONFIG_DIRS[@]} -eq 0 ]; then
    echo "No Claude config directories found. Pass them as arguments:"
    echo "  $0 ~/.claude ~/.claude-work"
    exit 1
fi

# --- Configure each profile ---
for config_dir in "${CONFIG_DIRS[@]}"; do
    config_dir="$(realpath "$config_dir" 2>/dev/null || echo "$config_dir")"
    if [ ! -d "$config_dir" ]; then
        echo "Skipping $config_dir (directory not found)"
        continue
    fi

    python3 - "$INSTALL_PATH" "$config_dir" <<'PYEOF'
import json, sys, os

install_path = sys.argv[1]
config_dir   = sys.argv[2]
settings_path = os.path.join(config_dir, 'settings.json')

# Use ~/... shorthand in stored paths so they survive home-dir moves
home = os.path.expanduser('~')
def tilde(p):
    return '~' + p[len(home):] if p.startswith(home + '/') else p

status_line = {
    "type": "command",
    "command": f"{tilde(install_path)} {tilde(config_dir)}",
    "refreshInterval": 60,
}

if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

settings["statusLine"] = status_line

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print(f"Configured: {settings_path}")
PYEOF
done

echo ""
echo "Done. Restart Claude Code (or open a new session) to see the status line."
