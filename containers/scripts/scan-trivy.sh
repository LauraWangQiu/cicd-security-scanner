#!/bin/bash
# Trivy container scanner
# Called by scan.sh dispatcher — do not run directly
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
IMAGE="${IMAGE:-}"

cd "$SCAN_PATH"

echo "[*] Tool: Trivy"

if [ -n "$IMAGE" ]; then
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
            echo "[*] No scannable container files — generating empty SARIF"
            echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Trivy","rules":[]}},"results":[]}]}' > /scan/results.sarif
        else
            echo "[*] Scanning $FILE_COUNT container file(s)..."
            trivy config \
                --severity "$SEVERITY" \
                --format sarif \
                --output /scan/results.sarif \
                "$TMP_DIR" || true
        fi
        rm -rf "$TMP_DIR"
    fi
else
    echo "No IMAGE specified, scanning Dockerfiles for misconfigurations..."
    trivy config \
        --severity "$SEVERITY" \
        --format sarif \
        --output /scan/results.sarif \
        "$SCAN_PATH" || true
fi
