#!/bin/bash
# Checkov IaC scanner
# Called by scan.sh dispatcher — do not run directly
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
FRAMEWORK="${FRAMEWORK:-all}"

cd "$SCAN_PATH"

echo "[*] Tool: Checkov"

IAC_PATTERNS="*.tf *.tfvars *.yml *.yaml Dockerfile docker-compose* *.json"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning only changed IaC files..."
    git fetch origin "$BASE_REF" --depth=1 2>/dev/null || true
    CHANGED_FILES=$(git diff --name-only --diff-filter=AMRC "origin/$BASE_REF"...HEAD -- $IAC_PATTERNS 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo "[*] No IaC files changed — generating empty SARIF"
        echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Checkov","rules":[]}},"results":[]}]}' > /scan/results.sarif
    else
        echo "[*] Changed IaC files:"
        echo "$CHANGED_FILES"
        FILE_ARGS=""
        for f in $CHANGED_FILES; do
            [ -f "$f" ] && FILE_ARGS="$FILE_ARGS --file $f"
        done

        if [ -z "$FILE_ARGS" ]; then
            echo "[*] No scannable IaC files in diff — generating empty SARIF"
            echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Checkov","rules":[]}},"results":[]}]}' > /scan/results.sarif
        else
            echo "[*] Scanning $(echo $CHANGED_FILES | wc -w) changed IaC file(s)..."
            checkov \
                $FILE_ARGS \
                --framework "$FRAMEWORK" \
                --output sarif \
                --output-file-path /scan \
                --soft-fail || true
        fi
    fi
else
    checkov \
        -d "$SCAN_PATH" \
        --framework "$FRAMEWORK" \
        --output sarif \
        --output-file-path /scan \
        --soft-fail || true
fi

# Rename output file (Checkov uses results_sarif.sarif)
if [ -f /scan/results_sarif.sarif ]; then
    mv /scan/results_sarif.sarif /scan/results.sarif
fi
