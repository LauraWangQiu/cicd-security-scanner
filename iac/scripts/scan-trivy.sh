#!/bin/bash
# Trivy — IaC scanner (config/misconfigurations mode)
# Called by scan.sh dispatcher — do not run directly
set -e

TOOL_NAME="Trivy"

IAC_PATTERNS="*.tf *.tfvars *.yml *.yaml Dockerfile docker-compose* *.json"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning changed IaC files..."
    # shellcheck disable=SC2086
    if get_changed_files $IAC_PATTERNS; then
        copy_to_tmpdir "iac"
        if [ "$SCAN_FILE_COUNT" -gt 0 ]; then
            trivy config "$TMP_SCAN_DIR" \
                --severity "$SEVERITY" \
                --format sarif --output "$RESULTS_FILE" \
                2>/dev/null || true
            cleanup_tmpdir
        else
            write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
        fi
    else
        write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
    fi
else
    trivy config "$SCAN_PATH" \
        --severity "$SEVERITY" \
        --format sarif --output "$RESULTS_FILE" \
        2>/dev/null || true
fi
