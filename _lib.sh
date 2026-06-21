# Shared helpers sourced by install.sh and uninstall.sh. Not meant to be run directly.

SCRIPT_NAME="claude-code-usage-status-line.py"
USER_BIN_CANDIDATES=("$HOME/bin" "$HOME/.local/bin")

# Sets BIN_DIR (string) and CONFIG_DIRS (array) from command-line arguments.
# If no config dirs are given, auto-detects ~/.claude and ~/.claude-* directories.
# Call as: parse_args "$@"
parse_args() {
    BIN_DIR=""
    CONFIG_DIRS=()

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
                CONFIG_DIRS+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#CONFIG_DIRS[@]} -eq 0 ]]; then
        [[ -d "$HOME/.claude" ]] && CONFIG_DIRS+=("$HOME/.claude")
        # nullglob so a non-matching glob expands to nothing instead of the
        # literal pattern (which would otherwise iterate once and fail -d).
        shopt -s nullglob
        for dir in "$HOME"/.claude-*; do
            [[ -d "$dir" ]] && CONFIG_DIRS+=("$dir")
        done
        shopt -u nullglob
    fi

    # Never let the exit status of the last test above propagate out: under
    # `set -e` a failing -d check here would abort the caller.
    return 0
}
