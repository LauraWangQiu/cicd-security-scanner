#!/bin/bash
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-ERROR,WARNING}"
CONFIG="${SEMGREP_CONFIG:-auto}"

echo "🔍 Running Semgrep SAST scan..."

# Run semgrep with SARIF output
# --no-git-ignore: Don't use git to find files (fixes issues with mounted volumes)
semgrep \
    --config "$CONFIG" \
    --sarif \
    --no-git-ignore \
    --output /scan/results.sarif \
    "$SCAN_PATH" || true

# Post-process SARIF: fix paths, remove duplicates with other scanners
if [ -f /scan/results.sarif ]; then
    jq --indent 2 '
      # Remove results handled by dedicated scanners (secrets, IaC, containers)
      .runs[].results |= [.[] | select(
        (.ruleId | test("secrets") | not) and
        (.ruleId | test("^yaml\\.docker-compose\\.") | not) and
        (.ruleId | test("^yaml\\.kubernetes\\.") | not) and
        (.ruleId | test("^terraform\\.") | not)
      )] |
      # Fix /scan/ paths to relative paths
      walk(if type == "string" then gsub("^/scan/"; "") else . end)
    ' /scan/results.sarif > /scan/results.sarif.tmp && mv /scan/results.sarif.tmp /scan/results.sarif
    
    # Count findings from SARIF
    TOTAL=$(jq '.runs[0].results | length' /scan/results.sarif 2>/dev/null || echo "0")
    
    echo ""
    echo "📊 SAST Results Summary:"
    echo "   Total findings: $TOTAL"
fi

echo "✅ SAST scan complete. Results in /scan/results.sarif"
