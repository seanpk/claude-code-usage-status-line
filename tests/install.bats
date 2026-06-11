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

@test "statusLine command references the config dir" {
    "$REPO/install.sh" --bin-dir "$BIN" "$CFG"
    run python3 -c "
import json, os
d = json.load(open('$CFG/settings.json'))
cmd = d['statusLine']['command']
home = os.path.expanduser('~')
cfg_tilde = '~' + '$CFG'[len(home):]
assert '$CFG' in cmd or cfg_tilde in cmd, f'config dir not in command: {cmd}'
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

@test "each config dir references itself in the command" {
    "$REPO/install.sh" --bin-dir "$BIN" "$CFG" "$CFG2"
    run python3 -c "
import json, os
home = os.path.expanduser('~')
def tilde(p):
    return '~' + p[len(home):] if p.startswith(home + '/') else p

for cfg in ['$CFG', '$CFG2']:
    d = json.load(open(cfg + '/settings.json'))
    cmd = d['statusLine']['command']
    assert tilde(cfg) in cmd or cfg in cmd, f'{cfg} not in command: {cmd}'
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
