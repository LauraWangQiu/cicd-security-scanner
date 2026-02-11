#!/bin/bash
set -e

IMAGE="${IMAGE:-}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
SCAN_PATH="${SCAN_PATH:-/scan}"

echo "🐳 Running Trivy Container Scan..."

if [ -n "$IMAGE" ]; then
    # Scan a specific container image
    echo "Scanning image: $IMAGE"
    trivy image \
        --severity "$SEVERITY" \
        --format sarif \
        --output /scan/results.sarif \
        "$IMAGE" || true
else
    # Scan Dockerfiles in the repository for misconfigurations
    echo "No IMAGE specified, scanning Dockerfiles for misconfigurations..."
    trivy config \
        --severity "$SEVERITY" \
        --format sarif \
        --output /scan/results.sarif \
        "$SCAN_PATH" || true
fi

# Format output, fix /scan/ paths
if [ -f /scan/results.sarif ]; then
    jq --indent 2 '
      walk(if type == "string" then gsub("^/scan/"; "") else . end)
    ' /scan/results.sarif > /scan/results.sarif.tmp && mv /scan/results.sarif.tmp /scan/results.sarif

    TOTAL=$(jq '.runs[0].results | length' /scan/results.sarif 2>/dev/null || echo "0")
    echo ""
    echo "📊 Container Scan Results:"
    echo "   Total findings: $TOTAL"
fi

echo "✅ Container scan complete. Results in /scan/results.sarif"
