setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TMP="$REPO/tmp/$BATS_TEST_NUMBER"
    BIN="$TMP/bin"
    CFG="$TMP/claude"
    CFG2="$TMP/claude-work"
    mkdir -p "$BIN" "$CFG" "$CFG2"
    # Pre-install so uninstall tests have something to remove
    "$REPO/install.sh" --bin-dir "$BIN" "$CFG" "$CFG2" >/dev/null 2>&1
}

teardown() {
    rm -rf "$TMP"
}

@test "removes script from --bin-dir" {
    [ -f "$BIN/claude-code-usage-status-line.py" ]
    run "$REPO/uninstall.sh" --bin-dir "$BIN" "$CFG"
    [ "$status" -eq 0 ]
    [ ! -f "$BIN/claude-code-usage-status-line.py" ]
}

@test "clears statusLine from settings.json" {
    run "$REPO/uninstall.sh" --bin-dir "$BIN" "$CFG"
    [ "$status" -eq 0 ]
    run python3 -c "
import json
d = json.load(open('$CFG/settings.json'))
assert 'statusLine' not in d, 'statusLine was not removed'
"
    [ "$status" -eq 0 ]
}

@test "preserves other keys when clearing statusLine" {
    python3 -c "
import json
with open('$CFG/settings.json') as f:
    d = json.load(f)
d['model'] = 'claude-opus-4-8'
with open('$CFG/settings.json', 'w') as f:
    json.dump(d, f)
"
    "$REPO/uninstall.sh" --bin-dir "$BIN" "$CFG"
    run python3 -c "
import json
d = json.load(open('$CFG/settings.json'))
assert d.get('model') == 'claude-opus-4-8', 'model key was lost'
assert 'statusLine' not in d, 'statusLine was not removed'
"
    [ "$status" -eq 0 ]
}

@test "clears statusLine from multiple config dirs" {
    run "$REPO/uninstall.sh" --bin-dir "$BIN" "$CFG" "$CFG2"
    [ "$status" -eq 0 ]
    run python3 -c "
import json
for cfg in ['$CFG', '$CFG2']:
    d = json.load(open(cfg + '/settings.json'))
    assert 'statusLine' not in d, f'statusLine not removed from {cfg}'
"
    [ "$status" -eq 0 ]
}

@test "reports gracefully when script is already gone" {
    rm "$BIN/claude-code-usage-status-line.py"
    run "$REPO/uninstall.sh" --bin-dir "$BIN" "$CFG"
    [ "$status" -eq 0 ]
    [[ "$output" == *"already removed"* ]]
}

@test "reports gracefully when settings.json has no statusLine" {
    echo '{"model": "claude-opus-4-8"}' > "$CFG/settings.json"
    run "$REPO/uninstall.sh" --bin-dir "$BIN" "$CFG"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No statusLine"* ]]
}

@test "reports gracefully when settings.json does not exist" {
    rm "$CFG/settings.json"
    run "$REPO/uninstall.sh" --bin-dir "$BIN" "$CFG"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No settings.json"* ]]
}

@test "skips nonexistent config dir with a message" {
    run "$REPO/uninstall.sh" --bin-dir "$BIN" "$CFG" "$TMP/nonexistent"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipping"* ]]
}

@test "short -d flag works like --bin-dir" {
    run "$REPO/uninstall.sh" -d "$BIN" "$CFG"
    [ "$status" -eq 0 ]
    [ ! -f "$BIN/claude-code-usage-status-line.py" ]
}
