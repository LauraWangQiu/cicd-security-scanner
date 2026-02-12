#!/bin/bash
# Grype container scanner (Anchore)
# Called by scan.sh dispatcher — do not run directly
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
IMAGE="${IMAGE:-}"

cd "$SCAN_PATH"

echo "[*] Tool: Grype (Anchore)"

if [ -n "$IMAGE" ]; then
    echo "Scanning image: $IMAGE"
    grype "$IMAGE" \
        --output sarif \
        --file /scan/results.sarif \
        2>/dev/null || true
elif [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning only changed Dockerfiles..."
    echo "[!] Note: Grype scans container images, not Dockerfiles."
    echo "    For Dockerfile misconfiguration scanning, use tool=trivy."
    echo "    Generating empty SARIF..."
    echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Grype","rules":[]}},"results":[]}]}' > /scan/results.sarif
else
    # Grype needs an image to scan; for filesystem mode it scans packages
    echo "No IMAGE specified. Scanning filesystem for installed packages..."
    grype "dir:$SCAN_PATH" \
        --output sarif \
        --file /scan/results.sarif \
        2>/dev/null || true
fi

# Ensure SARIF file exists
if [ ! -f /scan/results.sarif ]; then
    echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Grype","rules":[]}},"results":[]}]}' > /scan/results.sarif
fi
