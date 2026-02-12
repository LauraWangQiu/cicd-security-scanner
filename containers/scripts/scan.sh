#!/bin/bash
set -e

IMAGE="${IMAGE:-}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
SCAN_PATH="${SCAN_PATH:-/scan}"
SCAN_MODE="${SCAN_MODE:-full}"
BASE_REF="${GITHUB_BASE_REF:-main}"

echo "🐳 Running Trivy Container Scan..."
echo "   Mode: $SCAN_MODE"

git config --global --add safe.directory "$SCAN_PATH"
cd "$SCAN_PATH"

if [ -n "$IMAGE" ]; then
    # Scan a specific container image (always full)
    echo "Scanning image: $IMAGE"
    trivy image \
        --severity "$SEVERITY" \
        --format sarif \
        --output /scan/results.sarif \
        "$IMAGE" || true
elif [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning only changed Dockerfiles..."
    git fetch origin "$BASE_REF" --depth=1 2>/dev/null || true
    CHANGED_FILES=$(git diff --name-only --diff-filter=AMRC "origin/$BASE_REF"...HEAD -- 'Dockerfile*' '**/Dockerfile*' 'docker-compose*' '**/docker-compose*' 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo "[*] No Dockerfiles changed — generating empty SARIF"
        echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Trivy","rules":[]}},"results":[]}]}' > /scan/results.sarif
    else
        echo "[*] Changed container files:"
        echo "$CHANGED_FILES"
        
        # Copy changed files to temp dir preserving structure, then run trivy ONCE
        TMP_DIR="/tmp/container_scan_$$"
        mkdir -p "$TMP_DIR"
        
        FILE_COUNT=0
        for f in $CHANGED_FILES; do
            [ ! -f "$f" ] && continue
            mkdir -p "$TMP_DIR/$(dirname "$f")"
            cp "$f" "$TMP_DIR/$f"
            FILE_COUNT=$((FILE_COUNT + 1))
        done

        if [ "$FILE_COUNT" -eq 0 ]; then
            echo "[*] No scannable container files in diff — generating empty SARIF"
            echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Trivy","rules":[]}},"results":[]}]}' > /scan/results.sarif
        else
            echo "[*] Scanning $FILE_COUNT container file(s) in single trivy run..."
            trivy config \
                --severity "$SEVERITY" \
                --format sarif \
                --output /scan/results.sarif \
                "$TMP_DIR" || true
        fi
        rm -rf "$TMP_DIR"
    fi
else
    # Full scan mode: scan all Dockerfiles for misconfigurations
    echo "No IMAGE specified, scanning Dockerfiles for misconfigurations..."
    trivy config \
        --severity "$SEVERITY" \
        --format sarif \
        --output /scan/results.sarif \
        "$SCAN_PATH" || true
fi

# Format output, fix paths (remove /scan/ and temp dir prefixes)
if [ -f /scan/results.sarif ]; then
    jq --indent 2 '
      walk(if type == "string" then gsub("^/scan/"; "") | gsub("^/tmp/container_scan_[0-9]+/"; "") else . end)
    ' /scan/results.sarif > /scan/results.sarif.tmp && mv /scan/results.sarif.tmp /scan/results.sarif

    TOTAL=$(jq '.runs[0].results | length' /scan/results.sarif 2>/dev/null || echo "0")
    echo ""
    echo "📊 Container Scan Results:"
    echo "   Total findings: $TOTAL"
fi

echo "✅ Container scan complete. Results in /scan/results.sarif"
