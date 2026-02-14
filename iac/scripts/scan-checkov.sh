#!/bin/bash
# Checkov — IaC scanner
# Called by scan.sh dispatcher — do not run directly
set -e

TOOL_NAME="Checkov"

IAC_PATTERNS="*.tf *.tfvars *.yml *.yaml Dockerfile docker-compose* *.json"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning changed IaC files..."
    # shellcheck disable=SC2086
    if get_changed_files $IAC_PATTERNS; then
        # Checkov supports --file per file, so pass them individually
        FILE_ARGS=""
        for f in "${CHANGED_FILES[@]}"; do
            [ -f "$f" ] && FILE_ARGS="$FILE_ARGS --file $f"
        done
        if [ -z "$FILE_ARGS" ]; then
            write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
        else
            echo "[*] Scanning ${#CHANGED_FILES[@]} IaC file(s)..."
            # shellcheck disable=SC2086
            checkov $FILE_ARGS \
                --framework "$FRAMEWORK" \
                --output sarif --output-file-path /scan \
                --soft-fail || true
            # Checkov writes results_sarif.sarif — rename it
            [ -f /scan/results_sarif.sarif ] && mv /scan/results_sarif.sarif "$RESULTS_FILE"
        fi
    else
        write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
    fi
else
    checkov -d "$SCAN_PATH" \
        --framework "$FRAMEWORK" \
        --output sarif --output-file-path /scan \
        --soft-fail || true
    [ -f /scan/results_sarif.sarif ] && mv /scan/results_sarif.sarif "$RESULTS_FILE"
fi
