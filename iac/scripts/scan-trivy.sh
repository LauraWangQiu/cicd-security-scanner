#!/bin/bash
# Trivy IaC scanner (config mode)
# Called by scan.sh dispatcher — do not run directly
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"

cd "$SCAN_PATH"

echo "[*] Tool: Trivy (IaC config mode)"

IAC_PATTERNS="*.tf *.tfvars *.yml *.yaml Dockerfile docker-compose* *.json"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning only changed IaC files..."
    git fetch origin "$BASE_REF" --depth=1 2>/dev/null || true
    CHANGED_FILES=$(git diff --name-only --diff-filter=AMRC "origin/$BASE_REF"...HEAD -- $IAC_PATTERNS 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo "[*] No IaC files changed — generating empty SARIF"
        echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Trivy","rules":[]}},"results":[]}]}' > /scan/results.sarif
    else
        echo "[*] Changed IaC files:"
        echo "$CHANGED_FILES"

        TMP_DIR="/tmp/iac_scan_$$"
        mkdir -p "$TMP_DIR"

        FILE_COUNT=0
        for f in $CHANGED_FILES; do
            [ ! -f "$f" ] && continue
            mkdir -p "$TMP_DIR/$(dirname "$f")"
            cp "$f" "$TMP_DIR/$f"
            FILE_COUNT=$((FILE_COUNT + 1))
        done

        if [ "$FILE_COUNT" -eq 0 ]; then
            echo "[*] No scannable IaC files — generating empty SARIF"
            echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Trivy","rules":[]}},"results":[]}]}' > /scan/results.sarif
        else
            echo "[*] Scanning $FILE_COUNT IaC file(s)..."
            trivy config "$TMP_DIR" \
                --severity "$SEVERITY" \
                --format sarif \
                --output /scan/results.sarif \
                2>/dev/null || true
        fi
        rm -rf "$TMP_DIR"
    fi
else
    trivy config "$SCAN_PATH" \
        --severity "$SEVERITY" \
        --format sarif \
        --output /scan/results.sarif \
        2>/dev/null || true
fi

# Ensure SARIF file exists
if [ ! -f /scan/results.sarif ]; then
    echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Trivy","rules":[]}},"results":[]}]}' > /scan/results.sarif
fi
