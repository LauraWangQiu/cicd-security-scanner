#!/bin/bash
set -e

# ──────────────────────────────────────────────────────────────
#  Container Scanner Dispatcher
#  Selects the scanning tool based on the TOOL environment variable.
#  Supported tools: trivy (default), grype
#  To add a new tool, create scripts/scan-<toolname>.sh and add
#  it to the case below and the Dockerfile.
# ──────────────────────────────────────────────────────────────

TOOL="${TOOL:-trivy}"
IMAGE="${IMAGE:-}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
SCAN_PATH="${SCAN_PATH:-/scan}"
SCAN_MODE="${SCAN_MODE:-full}"
BASE_REF="${GITHUB_BASE_REF:-main}"

echo "🐳 Container Scanner"
echo "   Tool: $TOOL"
echo "   Mode: $SCAN_MODE"

git config --global --add safe.directory "$SCAN_PATH"
cd "$SCAN_PATH"

export SCAN_MODE BASE_REF SCAN_PATH SEVERITY IMAGE

SCRIPT_DIR="/scripts"

# Dispatch to tool-specific script
case "$TOOL" in
    trivy)
        source "$SCRIPT_DIR/scan-trivy.sh"
        ;;
    grype)
        source "$SCRIPT_DIR/scan-grype.sh"
        ;;
    *)
        echo "[!] Unknown TOOL: $TOOL"
        echo "    Supported tools: trivy, grype"
        echo ""
        echo "    To add a new tool:"
        echo "      1. Create scripts/scan-<toolname>.sh"
        echo "      2. Add it to the case in scan.sh"
        echo "      3. Install it in the Dockerfile"
        exit 1
        ;;
esac

# Format output, fix paths
if [ -f /scan/results.sarif ]; then
    jq --indent 2 '
      walk(if type == "string" then gsub("^/scan/"; "") | gsub("^/tmp/container_scan_[0-9]+/"; "") else . end)
    ' /scan/results.sarif > /scan/results.sarif.tmp && mv /scan/results.sarif.tmp /scan/results.sarif

    TOTAL=$(jq '.runs[0].results | length' /scan/results.sarif 2>/dev/null || echo "0")
    echo ""
    echo "📊 Container Scan Results:"
    echo "   Total findings: $TOTAL"
fi

echo "✅ Container scan complete. Results in /scan/results.sarif"
