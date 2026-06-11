#!/usr/bin/env bash
# Removes claude-code-usage-status-line.py and clears statusLine from Claude Code profiles.
#
# Usage:
#   ./uninstall.sh                                         # auto-detect bin dir and profiles
#   ./uninstall.sh --bin-dir ~/.local/bin                  # specify where the script was installed
#   ./uninstall.sh ~/.claude ~/.claude-home ~/.claude-work  # configure specific profiles
#   ./uninstall.sh --bin-dir ~/bin ~/.claude ~/.claude-work # both

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

parse_args "$@"

# --- Remove the script ---
if [[ -n "$BIN_DIR" ]]; then
    target="$BIN_DIR/$SCRIPT_NAME"
    if [[ -f "$target" ]]; then
        rm "$target"
        echo "Removed: $target"
    else
        echo "Script not found at $target (already removed?)"
    fi
else
    removed=0
    for candidate in "${USER_BIN_CANDIDATES[@]}"; do
        target="$candidate/$SCRIPT_NAME"
        if [[ -f "$target" ]]; then
            rm "$target"
            echo "Removed: $target"
            removed=1
        fi
    done
    if [[ $removed -eq 0 ]]; then
        echo "Script not found in ${USER_BIN_CANDIDATES[*]} (already removed?)"
    fi
fi

# --- Clear statusLine from each profile ---
if [[ ${#CONFIG_DIRS[@]} -eq 0 ]]; then
    echo "No Claude config directories found."
    exit 0
fi

for config_dir in "${CONFIG_DIRS[@]}"; do
    config_dir="$(realpath "$config_dir" 2>/dev/null || echo "$config_dir")"
    if [[ ! -d "$config_dir" ]]; then
        echo "Skipping $config_dir (directory not found)"
        continue
    fi

    python3 - "$config_dir" <<'PYEOF'
import json, sys, os

config_dir    = sys.argv[1]
settings_path = os.path.join(config_dir, 'settings.json')

if not os.path.exists(settings_path):
    print(f"No settings.json: {settings_path}")
    sys.exit(0)

with open(settings_path) as f:
    settings = json.load(f)

if 'statusLine' not in settings:
    print(f"No statusLine to remove: {settings_path}")
    sys.exit(0)

del settings['statusLine']

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print(f"Cleared statusLine: {settings_path}")
PYEOF
done

echo ""
echo "Done."
