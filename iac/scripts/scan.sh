#!/bin/bash
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
FRAMEWORK="${FRAMEWORK:-all}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"

echo "🔍 Running Checkov IaC scan..."

# Run checkov with SARIF output
checkov \
    -d "$SCAN_PATH" \
    --framework "$FRAMEWORK" \
    --output sarif \
    --output-file-path /scan \
    --soft-fail || true

# Rename output file
if [ -f /scan/results_sarif.sarif ]; then
    mv /scan/results_sarif.sarif /scan/results.sarif
fi

# Format output, fix /scan/ paths
if [ -f /scan/results.sarif ]; then
    jq --indent 2 '
      walk(if type == "string" then gsub("^/scan/"; "") else . end)
    ' /scan/results.sarif > /scan/results.sarif.tmp && mv /scan/results.sarif.tmp /scan/results.sarif

    TOTAL=$(jq '.runs[0].results | length' /scan/results.sarif 2>/dev/null || echo "0")
    echo ""
    echo "📊 IaC Results Summary:"
    echo "   Total findings: $TOTAL"
fi

echo "✅ IaC scan complete. Results in /scan/results.sarif"
