#!/bin/bash
# Gitleaks — secret scanner
# Called by scan.sh dispatcher — do not run directly
set -e

TOOL_NAME="Gitleaks"

case "$SCAN_MODE" in
    pr)
        echo "[*] PR mode: scanning changed files..."
        if get_changed_files '*'; then
            copy_to_tmpdir "gitleaks"
            if [ "$SCAN_FILE_COUNT" -gt 0 ]; then
                gitleaks dir "$TMP_SCAN_DIR" \
                    --report-format sarif \
                    --report-path "$RESULTS_FILE" \
                    --redact || true
                cleanup_tmpdir
            else
                write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
            fi
        else
            write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
        fi
        ;;
    history)
        echo "[*] Scanning entire git history..."
        gitleaks detect --source="." \
            --report-format sarif \
            --report-path "$RESULTS_FILE" \
            --redact || true
        ;;
    files|*)
        echo "[*] Scanning current files..."
        gitleaks dir . \
            --report-format sarif \
            --report-path "$RESULTS_FILE" \
            --redact || true
        ;;
esac
