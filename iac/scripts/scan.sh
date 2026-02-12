#!/bin/bash
set -e

# ──────────────────────────────────────────────────────────────
#  IaC Scanner Dispatcher
#  Selects the scanning tool based on the TOOL environment variable.
#  Supported tools: checkov (default), trivy
#  To add a new tool, create scripts/scan-<toolname>.sh and add
#  it to the case below and the Dockerfile.
# ──────────────────────────────────────────────────────────────

TOOL="${TOOL:-checkov}"
SCAN_PATH="${SCAN_PATH:-/scan}"
FRAMEWORK="${FRAMEWORK:-all}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
SCAN_MODE="${SCAN_MODE:-full}"
BASE_REF="${GITHUB_BASE_REF:-main}"

echo "🏗️ IaC Scanner"
echo "   Tool: $TOOL"
echo "   Mode: $SCAN_MODE"

git config --global --add safe.directory "$SCAN_PATH"
cd "$SCAN_PATH"

export SCAN_MODE BASE_REF SCAN_PATH FRAMEWORK SEVERITY

SCRIPT_DIR="/scripts"

# Dispatch to tool-specific script
case "$TOOL" in
    checkov)
        source "$SCRIPT_DIR/scan-checkov.sh"
        ;;
    trivy)
        source "$SCRIPT_DIR/scan-trivy.sh"
        ;;
    *)
        echo "[!] Unknown TOOL: $TOOL"
        echo "    Supported tools: checkov, trivy"
        echo ""
        echo "    To add a new tool:"
        echo "      1. Create scripts/scan-<toolname>.sh"
        echo "      2. Add it to the case in scan.sh"
        echo "      3. Install it in the Dockerfile"
        exit 1
        ;;
esac

# Format output, fix /scan/ paths
if [ -f /scan/results.sarif ]; then
    jq --indent 2 '
      walk(if type == "string" then gsub("^/scan/"; "") | gsub("^/tmp/iac_scan_[0-9]+/"; "") else . end)
    ' /scan/results.sarif > /scan/results.sarif.tmp && mv /scan/results.sarif.tmp /scan/results.sarif

    TOTAL=$(jq '.runs[0].results | length' /scan/results.sarif 2>/dev/null || echo "0")
    echo ""
    echo "📊 IaC Results Summary:"
    echo "   Total findings: $TOTAL"
fi

echo "✅ IaC scan complete. Results in /scan/results.sarif"
