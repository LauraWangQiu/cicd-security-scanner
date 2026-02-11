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

# Format output, fix /scan/ paths
if [ -f "/scan/$OUTPUT_FILE" ]; then
    jq --indent 2 '
      walk(if type == "string" then gsub("^/scan/"; "") else . end)
    ' "/scan/$OUTPUT_FILE" > "/scan/${OUTPUT_FILE}.tmp" && mv "/scan/${OUTPUT_FILE}.tmp" "/scan/$OUTPUT_FILE"

    VULN_COUNT=$(jq '.runs[0].results | length' "/scan/$OUTPUT_FILE" 2>/dev/null || echo 0)
    echo "✅ Scan complete. Found $VULN_COUNT vulnerability(ies) with severity $SEVERITY or higher."
else
    echo "⚠️ No results file generated."
fi
