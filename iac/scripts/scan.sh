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

# Also generate JSON for detailed analysis
checkov \
    -d "$SCAN_PATH" \
    --framework "$FRAMEWORK" \
    --output json \
    --output-file-path /scan \
    --soft-fail || true

if [ -f /scan/results_json.json ]; then
    mv /scan/results_json.json /scan/results.json
fi

# Count findings
if [ -f /scan/results.json ]; then
    PASSED=$(jq '.results.passed_checks | length' /scan/results.json 2>/dev/null || echo "0")
    FAILED=$(jq '.results.failed_checks | length' /scan/results.json 2>/dev/null || echo "0")
    SKIPPED=$(jq '.results.skipped_checks | length' /scan/results.json 2>/dev/null || echo "0")
    
    echo ""
    echo "📊 IaC Results Summary:"
    echo "   Passed: $PASSED"
    echo "   Failed: $FAILED"
    echo "   Skipped: $SKIPPED"
fi

echo "✅ IaC scan complete. Results in /scan/results.sarif"
