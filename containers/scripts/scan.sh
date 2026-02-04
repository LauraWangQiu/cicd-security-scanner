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

    trivy image \
        --severity "$SEVERITY" \
        --format json \
        --output /scan/results.json \
        "$IMAGE" || true
else
    # Scan Dockerfiles in the repository for misconfigurations
    echo "No IMAGE specified, scanning Dockerfiles for misconfigurations..."
    trivy config \
        --severity "$SEVERITY" \
        --format sarif \
        --output /scan/results.sarif \
        "$SCAN_PATH" || true

    trivy config \
        --severity "$SEVERITY" \
        --format json \
        --output /scan/results.json \
        "$SCAN_PATH" || true
fi

# Count findings
if [ -f /scan/results.json ]; then
    if [ -n "$IMAGE" ]; then
        CRITICAL=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' /scan/results.json 2>/dev/null || echo "0")
        HIGH=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' /scan/results.json 2>/dev/null || echo "0")
        MEDIUM=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "MEDIUM")] | length' /scan/results.json 2>/dev/null || echo "0")
        
        echo ""
        echo "📊 Container Scan Results:"
        echo "   Critical: $CRITICAL"
        echo "   High: $HIGH"
        echo "   Medium: $MEDIUM"
    else
        MISCONFIGS=$(jq '.Results[]?.Misconfigurations | length' /scan/results.json 2>/dev/null || echo "0")
        echo ""
        echo "📊 Dockerfile Scan Results:"
        echo "   Misconfigurations: $MISCONFIGS"
    fi
fi

echo "✅ Container scan complete. Results in /scan/results.sarif"
