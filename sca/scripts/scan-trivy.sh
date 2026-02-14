#!/bin/bash
# Trivy — SCA scanner (dependency vulnerabilities)
# Called by scan.sh dispatcher — do not run directly
set -e

TOOL_NAME="Trivy"

DEP_PATTERNS="requirements*.txt Pipfile* poetry.lock pyproject.toml package.json package-lock.json yarn.lock pnpm-lock.yaml go.sum go.mod Gemfile.lock Cargo.lock composer.lock *.csproj *.sln"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning changed dependency files..."
    # shellcheck disable=SC2086
    if get_changed_files $DEP_PATTERNS; then
        copy_to_tmpdir "sca"
        if [ "$SCAN_FILE_COUNT" -gt 0 ]; then
            trivy filesystem "$TMP_SCAN_DIR" \
                --scanners vuln --severity "$SEVERITY" \
                --format sarif --output "$RESULTS_FILE" \
                --exit-code 0 || true
            cleanup_tmpdir
        else
            write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
        fi
    else
        write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
    fi
else
    trivy filesystem "$SCAN_PATH" \
        --scanners vuln --severity "$SEVERITY" \
        --format sarif --output "$RESULTS_FILE" \
        --exit-code 0 || true
fi
