#!/bin/bash
# Semgrep — SAST scanner
# Called by scan.sh dispatcher — do not run directly
set -e

TOOL_NAME="Semgrep"
CONFIG="${SEMGREP_CONFIG:-auto}"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning changed files..."
    if get_changed_files '*'; then
        copy_to_tmpdir "semgrep"
        if [ "$SCAN_FILE_COUNT" -gt 0 ]; then
            semgrep --config "$CONFIG" --sarif --no-git-ignore \
                --output "$RESULTS_FILE" "$TMP_SCAN_DIR" || true
            cleanup_tmpdir
        else
            write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
        fi
    else
        write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
    fi
else
    semgrep --config "$CONFIG" --sarif --no-git-ignore \
        --output "$RESULTS_FILE" "$SCAN_PATH" || true
fi
