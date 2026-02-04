#!/bin/bash
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-ERROR,WARNING}"
CONFIG="${SEMGREP_CONFIG:-auto}"

echo "🔍 Running Semgrep SAST scan..."

# Run semgrep with SARIF output
semgrep \
    --config "$CONFIG" \
    --sarif \
    --output /scan/results.sarif \
    "$SCAN_PATH" || true

# Also generate JSON for detailed analysis
semgrep \
    --config "$CONFIG" \
    --json \
    --output /scan/results.json \
    "$SCAN_PATH" || true

# Count findings
if [ -f /scan/results.json ]; then
    TOTAL=$(jq '.results | length' /scan/results.json 2>/dev/null || echo "0")
    ERRORS=$(jq '[.results[] | select(.extra.severity == "ERROR")] | length' /scan/results.json 2>/dev/null || echo "0")
    WARNINGS=$(jq '[.results[] | select(.extra.severity == "WARNING")] | length' /scan/results.json 2>/dev/null || echo "0")
    
    echo ""
    echo "📊 SAST Results Summary:"
    echo "   Total findings: $TOTAL"
    echo "   Errors: $ERRORS"
    echo "   Warnings: $WARNINGS"
fi

echo "✅ SAST scan complete. Results in /scan/results.sarif"
