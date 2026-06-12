#!/usr/bin/env bash
# Installs claude-code-usage-status-line.py and configures statusLine in Claude Code profiles.
#
# Usage:
#   ./install.sh                                         # auto-detect bin dir and profiles
#   ./install.sh --bin-dir ~/.local/bin                  # specify install location
#   ./install.sh ~/.claude ~/.claude-home ~/.claude-work  # configure specific profiles
#   ./install.sh --bin-dir ~/bin ~/.claude ~/.claude-work # both

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

parse_args "$@"

# --- Resolve bin directory ---
if [[ -n "$BIN_DIR" ]]; then
    mkdir -p "$BIN_DIR"
else
    for candidate in "${USER_BIN_CANDIDATES[@]}"; do
        if [[ -d "$candidate" ]]; then
            BIN_DIR="$candidate"
            break
        fi
    done

    if [[ -z "$BIN_DIR" ]]; then
        echo "Error: no suitable bin directory found." >&2
        printf '  Tried: %s\n' "${USER_BIN_CANDIDATES[@]}" >&2
        echo "" >&2
        echo "Create one and re-run, e.g.:" >&2
        echo "  mkdir -p ~/.local/bin && ./install.sh --bin-dir ~/.local/bin" >&2
        exit 1
    fi
fi

# Warn if the chosen dir is not on PATH
if ! printf ':%s:' "$PATH" | grep -q ":${BIN_DIR}:"; then
    echo "Warning: $BIN_DIR is not in your PATH." >&2
    echo "  Add it to your shell profile, e.g.:" >&2
    echo "    export PATH=\"$BIN_DIR:\$PATH\"" >&2
    echo "" >&2
fi

# --- Install the script ---
INSTALL_PATH="$BIN_DIR/$SCRIPT_NAME"
cp "$SCRIPT_DIR/$SCRIPT_NAME" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
echo "Installed: $INSTALL_PATH"

# --- Configure each profile ---
if [[ ${#CONFIG_DIRS[@]} -eq 0 ]]; then
    echo "No Claude config directories found. Pass them as arguments:"
    echo "  $0 ~/.claude ~/.claude-work"
    exit 1
fi

for config_dir in "${CONFIG_DIRS[@]}"; do
    config_dir="$(realpath "$config_dir" 2>/dev/null || echo "$config_dir")"
    if [[ ! -d "$config_dir" ]]; then
        echo "Skipping $config_dir (directory not found)"
        continue
    fi

    python3 - "$INSTALL_PATH" "$config_dir" <<'PYEOF'
import json, sys, os

install_path = sys.argv[1]
config_dir   = sys.argv[2]
settings_path = os.path.join(config_dir, 'settings.json')

home = os.path.expanduser('~')
def tilde(p):
    return '~' + p[len(home):] if p.startswith(home + '/') else p

status_line = {
    "type": "command",
    "command": tilde(install_path),
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
