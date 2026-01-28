#!/bin/bash
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
OUTPUT_FILE="${OUTPUT_FILE:-results.sarif}"

echo "🔍 Starting SCA scan with Trivy..."
echo "   Path: $SCAN_PATH"
echo "   Severity: $SEVERITY"

# Run Trivy filesystem scan for vulnerabilities
trivy filesystem "$SCAN_PATH" \
    --scanners vuln \
    --severity "$SEVERITY" \
    --format sarif \
    --output "/scan/$OUTPUT_FILE" \
    --exit-code 0

# Check if results file was created
if [ -f "/scan/$OUTPUT_FILE" ]; then
    VULN_COUNT=$(jq '.runs[0].results | length' "/scan/$OUTPUT_FILE" 2>/dev/null || echo 0)
    echo "✅ Scan complete. Found $VULN_COUNT vulnerability(ies) with severity $SEVERITY or higher."
else
    echo "⚠️ No results file generated."
fi
