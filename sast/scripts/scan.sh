#!/bin/bash
set -e

# ──────────────────────────────────────────────────────────────
#  SAST Scanner Dispatcher
#  Selects the scanning tool based on the TOOL environment variable.
#  Supported tools: semgrep (default), bandit
#  To add a new tool, create scripts/scan-<toolname>.sh and add
#  it to the case below and the Dockerfile.
# ──────────────────────────────────────────────────────────────

TOOL="${TOOL:-semgrep}"
SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-ERROR,WARNING}"
SCAN_MODE="${SCAN_MODE:-full}"
BASE_REF="${GITHUB_BASE_REF:-main}"

echo "🔍 SAST Scanner"
echo "   Tool: $TOOL"
echo "   Mode: $SCAN_MODE"

git config --global --add safe.directory "$SCAN_PATH"
cd "$SCAN_PATH"

export SCAN_MODE BASE_REF SCAN_PATH SEVERITY

SCRIPT_DIR="/scripts"

# Dispatch to tool-specific script
case "$TOOL" in
    semgrep)
        source "$SCRIPT_DIR/scan-semgrep.sh"
        ;;
    bandit)
        source "$SCRIPT_DIR/scan-bandit.sh"
        ;;
    *)
        echo "[!] Unknown TOOL: $TOOL"
        echo "    Supported tools: semgrep, bandit"
        echo ""
        echo "    To add a new tool:"
        echo "      1. Create scripts/scan-<toolname>.sh"
        echo "      2. Add it to the case in scan.sh"
        echo "      3. Install it in the Dockerfile"
        exit 1
        ;;
esac

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
    
    TOTAL=$(jq '.runs[0].results | length' /scan/results.sarif 2>/dev/null || echo "0")
    
    echo ""
    echo "📊 SAST Results Summary:"
    echo "   Total findings: $TOTAL"
fi

echo "✅ SAST scan complete. Results in /scan/results.sarif"
