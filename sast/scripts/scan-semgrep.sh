#!/bin/bash
# Semgrep SAST scanner
# Called by scan.sh dispatcher — do not run directly
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
CONFIG="${SEMGREP_CONFIG:-auto}"

cd "$SCAN_PATH"

echo "[*] Tool: Semgrep"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning only changed files..."
    git fetch origin "$BASE_REF" --depth=1 2>/dev/null || true
    CHANGED_FILES=$(git diff --name-only --diff-filter=AMRC "origin/$BASE_REF"...HEAD 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo "[*] No changed files detected — generating empty SARIF"
        echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Semgrep","rules":[]}},"results":[]}]}' > /scan/results.sarif
    else
        FILE_ARGS=""
        for f in $CHANGED_FILES; do
            [ -f "$f" ] && FILE_ARGS="$FILE_ARGS $f"
        done

        if [ -z "$FILE_ARGS" ]; then
            echo "[*] No scannable files in diff — generating empty SARIF"
            echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Semgrep","rules":[]}},"results":[]}]}' > /scan/results.sarif
        else
            echo "[*] Scanning $(echo $FILE_ARGS | wc -w) changed file(s)..."
            semgrep \
                --config "$CONFIG" \
                --sarif \
                --no-git-ignore \
                --output /scan/results.sarif \
                $FILE_ARGS || true
        fi
    fi
else
    semgrep \
        --config "$CONFIG" \
        --sarif \
        --no-git-ignore \
        --output /scan/results.sarif \
        "$SCAN_PATH" || true
fi
