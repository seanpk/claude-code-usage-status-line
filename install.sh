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
SCRIPT_SRC="$SCRIPT_DIR/claude-code-usage-status-line.py"

# --- Parse arguments ---
BIN_DIR=""
CONFIG_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--bin-dir)
            [[ $# -lt 2 ]] && { echo "Error: $1 requires an argument" >&2; exit 1; }
            BIN_DIR="${2/#\~/$HOME}"
            shift 2
            ;;
        -d=*|--bin-dir=*)
            val="${1#*=}"
            BIN_DIR="${val/#\~/$HOME}"
            shift
            ;;
        -*)
            echo "Error: unknown option: $1" >&2
            echo "Usage: $0 [--bin-dir DIR] [config-dir ...]" >&2
            exit 1
            ;;
        *)
            CONFIG_ARGS+=("$1")
            shift
            ;;
    esac
done

# --- Resolve bin directory ---
# Common user-local bin directories, checked in order
USER_BIN_CANDIDATES=("$HOME/bin" "$HOME/.local/bin")

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
INSTALL_PATH="$BIN_DIR/claude-code-usage-status-line.py"
cp "$SCRIPT_SRC" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
echo "Installed: $INSTALL_PATH"

# --- Resolve which config dirs to configure ---
if [[ ${#CONFIG_ARGS[@]} -gt 0 ]]; then
    CONFIG_DIRS=("${CONFIG_ARGS[@]}")
else
    CONFIG_DIRS=()
    [[ -d "$HOME/.claude" ]] && CONFIG_DIRS+=("$HOME/.claude")
    for dir in "$HOME"/.claude-*; do
        [[ -d "$dir" ]] && CONFIG_DIRS+=("$dir")
    done
fi

if [[ ${#CONFIG_DIRS[@]} -eq 0 ]]; then
    echo "No Claude config directories found. Pass them as arguments:"
    echo "  $0 ~/.claude ~/.claude-work"
    exit 1
fi

# --- Configure each profile ---
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
