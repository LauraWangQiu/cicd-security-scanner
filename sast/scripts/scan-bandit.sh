#!/bin/bash
# Bandit — Python SAST scanner
# Called by scan.sh dispatcher — do not run directly
set -e

TOOL_NAME="Bandit"

# Convert severity to Bandit format (low/medium/high)
BANDIT_SEV=$(echo "$SEVERITY" | tr ',' '\n' | tr '[:upper:]' '[:lower:]' | \
    sed 's/critical/high/' | sort | head -1)
BANDIT_SEV="${BANDIT_SEV:-medium}"

echo "[*] Severity: $BANDIT_SEV"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning changed Python files..."
    if get_changed_files '*.py'; then
        copy_to_tmpdir "bandit"
        if [ "$SCAN_FILE_COUNT" -gt 0 ]; then
            bandit -r "$TMP_SCAN_DIR" \
                -f sarif -o "$RESULTS_FILE" \
                --severity-level "$BANDIT_SEV" \
                --exclude "*/.venv/*,*/venv/*,*/node_modules/*" \
                2>/dev/null || true
            cleanup_tmpdir
        else
            write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
        fi
    else
        write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
    fi
else
    # Check for Python files before scanning
    PY_FILES=$(find "$SCAN_PATH" -name "*.py" \
        -not -path "*/node_modules/*" \
        -not -path "*/.venv/*" \
        -not -path "*/venv/*" 2>/dev/null || true)

    if [ -z "$PY_FILES" ]; then
        echo "[*] No Python files found"
        write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
    else
        bandit -r "$SCAN_PATH" \
            -f sarif -o "$RESULTS_FILE" \
            --severity-level "$BANDIT_SEV" \
            --exclude "*/.venv/*,*/venv/*,*/node_modules/*" \
            2>/dev/null || true
    fi
fi
