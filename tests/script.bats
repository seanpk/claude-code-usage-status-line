SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/claude-code-usage-status-line.py"

run_with() {
    run bash -c "echo '$1' | python3 '$SCRIPT'"
}

@test "outputs nothing on empty stdin" {
    run bash -c "echo '{}' | python3 '$SCRIPT'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "shows basename of cwd" {
    run_with '{"workspace": {"current_dir": "/home/user/my-project"}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"my-project"* ]]
    [[ "$output" != *"/home/user"* ]]
}

@test "falls back to cwd field when workspace absent" {
    run_with '{"cwd": "/home/user/fallback-dir"}'
    [[ "$output" == *"fallback-dir"* ]]
}

@test "shows model display name" {
    run_with '{"model": {"display_name": "Sonnet"}}'
    [[ "$output" == *"Sonnet"* ]]
}

@test "appends effort level when present" {
    run_with '{"model": {"display_name": "Opus"}, "effort": {"level": "high"}}'
    [[ "$output" == *"Opus [high]"* ]]
}

@test "omits effort bracket when effort absent" {
    run_with '{"model": {"display_name": "Sonnet"}}'
    [[ "$output" != *"["* ]]
}

@test "shows rate limit bars when rate_limits present" {
    local now
    now=$(python3 -c "import time; print(int(time.time()) + 3600)")
    run_with "{\"rate_limits\": {\"five_hour\": {\"used_percentage\": 42, \"resets_at\": $now}, \"seven_day\": {\"used_percentage\": 10, \"resets_at\": $now}}}"
    [[ "$output" == *"5h"* ]]
    [[ "$output" == *"7d"* ]]
    [[ "$output" == *"42"* ]]
}

@test "omits rate limits section when absent" {
    run_with '{"model": {"display_name": "Sonnet"}}'
    [[ "$output" != *"5h"* ]]
    [[ "$output" != *"7d"* ]]
}

@test "shows context percentage" {
    run_with '{"context_window": {"used_percentage": 34}}'
    [[ "$output" == *"ctx"* ]]
    [[ "$output" == *"34"* ]]
}

@test "omits context section when used_percentage absent" {
    run_with '{"context_window": {}}'
    [[ "$output" != *"ctx"* ]]
}

@test "shows cache hit rate when current_usage present" {
    run_with '{"context_window": {"used_percentage": 20, "current_usage": {"input_tokens": 100, "cache_read_input_tokens": 400, "cache_creation_input_tokens": 100}}}'
    # cache hit = 400 / (100 + 400 + 100) = 66.7%
    [[ "$output" == *"cache"* ]]
}

@test "omits cache when current_usage is null" {
    run_with '{"context_window": {"used_percentage": 20, "current_usage": null}}'
    [[ "$output" != *"cache"* ]]
}

@test "omits cache when all token counts are zero" {
    run_with '{"context_window": {"used_percentage": 20, "current_usage": {"input_tokens": 0, "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0}}}'
    [[ "$output" != *"cache"* ]]
}

@test "sections are separated by pipe" {
    local now
    now=$(python3 -c "import time; print(int(time.time()) + 3600)")
    run_with "{\"workspace\": {\"current_dir\": \"/p/proj\"}, \"model\": {\"display_name\": \"Sonnet\"}, \"context_window\": {\"used_percentage\": 10}}"
    [[ "$output" == *"|"* ]]
}

@test "reset countdown shows minutes when under an hour" {
    local soon
    soon=$(python3 -c "import time; print(int(time.time()) + 1500)")  # 25 minutes
    run_with "{\"rate_limits\": {\"five_hour\": {\"used_percentage\": 50, \"resets_at\": $soon}}}"
    [[ "$output" == *"m"* ]]
}

@test "reset countdown shows hours when over an hour" {
    local later
    later=$(python3 -c "import time; print(int(time.time()) + 7200)")  # 2 hours
    run_with "{\"rate_limits\": {\"five_hour\": {\"used_percentage\": 50, \"resets_at\": $later}}}"
    [[ "$output" == *"h"* ]]
}
