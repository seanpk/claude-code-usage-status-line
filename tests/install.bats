setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TMP="$REPO/tmp/$BATS_TEST_NUMBER"
    BIN="$TMP/bin"
    CFG="$TMP/claude"
    CFG2="$TMP/claude-work"
    mkdir -p "$BIN" "$CFG" "$CFG2"
}

teardown() {
    rm -rf "$TMP"
}

@test "copies script to --bin-dir" {
    run "$REPO/install.sh" --bin-dir "$BIN" "$CFG"
    [ "$status" -eq 0 ]
    [ -f "$BIN/claude-code-usage-status-line.py" ]
}

@test "installed script is executable" {
    "$REPO/install.sh" --bin-dir "$BIN" "$CFG"
    [ -x "$BIN/claude-code-usage-status-line.py" ]
}

@test "creates settings.json when none exists" {
    [ ! -f "$CFG/settings.json" ]
    run "$REPO/install.sh" --bin-dir "$BIN" "$CFG"
    [ "$status" -eq 0 ]
    [ -f "$CFG/settings.json" ]
}

@test "statusLine has correct structure" {
    "$REPO/install.sh" --bin-dir "$BIN" "$CFG"
    run python3 -c "
import json
d = json.load(open('$CFG/settings.json'))
sl = d['statusLine']
assert sl['type'] == 'command', f'wrong type: {sl[\"type\"]}'
assert 'claude-code-usage-status-line.py' in sl['command'], f'script not in command: {sl[\"command\"]}'
assert sl['refreshInterval'] == 60, f'wrong interval: {sl[\"refreshInterval\"]}'
"
    [ "$status" -eq 0 ]
}

@test "statusLine command has no extra arguments" {
    "$REPO/install.sh" --bin-dir "$BIN" "$CFG"
    run python3 -c "
import json
d = json.load(open('$CFG/settings.json'))
cmd = d['statusLine']['command']
# Script reads session data from stdin — no config dir argument needed
assert cmd.count(' ') == 0, f'unexpected arguments in command: {cmd}'
"
    [ "$status" -eq 0 ]
}

@test "preserves existing keys in settings.json" {
    echo '{"model": "claude-opus-4-8", "theme": "dark"}' > "$CFG/settings.json"
    "$REPO/install.sh" --bin-dir "$BIN" "$CFG"
    run python3 -c "
import json
d = json.load(open('$CFG/settings.json'))
assert d.get('model') == 'claude-opus-4-8', 'model key was lost'
assert d.get('theme') == 'dark', 'theme key was lost'
assert 'statusLine' in d, 'statusLine was not added'
"
    [ "$status" -eq 0 ]
}

@test "overwrites stale statusLine" {
    echo '{"statusLine": {"type": "command", "command": "old-script", "refreshInterval": 60}}' > "$CFG/settings.json"
    "$REPO/install.sh" --bin-dir "$BIN" "$CFG"
    run python3 -c "
import json
d = json.load(open('$CFG/settings.json'))
assert 'old-script' not in d['statusLine']['command'], 'stale command not replaced'
"
    [ "$status" -eq 0 ]
}

@test "configures multiple config dirs" {
    run "$REPO/install.sh" --bin-dir "$BIN" "$CFG" "$CFG2"
    [ "$status" -eq 0 ]
    [ -f "$CFG/settings.json" ]
    [ -f "$CFG2/settings.json" ]
}

@test "all config dirs get the same command (no per-dir arg)" {
    "$REPO/install.sh" --bin-dir "$BIN" "$CFG" "$CFG2"
    run python3 -c "
import json
cmd1 = json.load(open('$CFG/settings.json'))['statusLine']['command']
cmd2 = json.load(open('$CFG2/settings.json'))['statusLine']['command']
assert cmd1 == cmd2, f'commands differ: {cmd1!r} vs {cmd2!r}'
"
    [ "$status" -eq 0 ]
}

@test "skips nonexistent config dir with a message" {
    run "$REPO/install.sh" --bin-dir "$BIN" "$CFG" "$TMP/nonexistent"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipping"* ]]
    [ -f "$CFG/settings.json" ]
}

@test "warns when bin dir is not in PATH" {
    run bash -c "\"$REPO/install.sh\" --bin-dir \"$BIN\" \"$CFG\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not in your PATH"* ]]
}

@test "creates bin dir with --bin-dir if it does not exist" {
    NEW_BIN="$TMP/newbin"
    [ ! -d "$NEW_BIN" ]
    run "$REPO/install.sh" --bin-dir "$NEW_BIN" "$CFG"
    [ "$status" -eq 0 ]
    [ -f "$NEW_BIN/claude-code-usage-status-line.py" ]
}

@test "short -d flag works like --bin-dir" {
    run "$REPO/install.sh" -d "$BIN" "$CFG"
    [ "$status" -eq 0 ]
    [ -f "$BIN/claude-code-usage-status-line.py" ]
}

# Regression: auto-detect must not abort under `set -e` when the only profile
# is the default ~/.claude and no ~/.claude-* profiles exist. The trailing -d
# test in parse_args used to leave a non-zero status and kill the script.
@test "auto-detects default ~/.claude with no ~/.claude-* profiles" {
    HOME_DIR="$TMP/home"
    mkdir -p "$HOME_DIR/.claude"
    run env HOME="$HOME_DIR" "$REPO/install.sh" --bin-dir "$BIN"
    [ "$status" -eq 0 ]
    [ -f "$HOME_DIR/.claude/settings.json" ]
}

# Regression: with no claude profiles, parse_args must not silently abort under
# `set -e`. install.sh should reach its own check and exit with a helpful message,
# not die mid-run inside parse_args.
@test "reports helpfully when no claude profiles exist" {
    HOME_DIR="$TMP/emptyhome"
    mkdir -p "$HOME_DIR"
    run env HOME="$HOME_DIR" "$REPO/install.sh" --bin-dir "$BIN"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No Claude config directories found"* ]]
}
