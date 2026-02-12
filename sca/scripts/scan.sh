#!/bin/bash
set -e

# ──────────────────────────────────────────────────────────────
#  SCA Scanner Dispatcher
#  Selects the scanning tool based on the TOOL environment variable.
#  Supported tools: trivy (default), grype
#  To add a new tool, create scripts/scan-<toolname>.sh and add
#  it to the case below and the Dockerfile.
# ──────────────────────────────────────────────────────────────

TOOL="${TOOL:-trivy}"
SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
OUTPUT_FILE="${OUTPUT_FILE:-results.sarif}"
SCAN_MODE="${SCAN_MODE:-full}"
BASE_REF="${GITHUB_BASE_REF:-main}"

echo "📦 SCA Scanner"
echo "   Tool: $TOOL"
echo "   Path: $SCAN_PATH"
echo "   Severity: $SEVERITY"

git config --global --add safe.directory "$SCAN_PATH"
cd "$SCAN_PATH"

export SCAN_MODE BASE_REF SCAN_PATH SEVERITY OUTPUT_FILE

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
if [ -f "/scan/$OUTPUT_FILE" ]; then
    jq --indent 2 '
      walk(if type == "string" then gsub("^/scan/"; "") | gsub("^/tmp/sca_scan_[0-9]+/"; "") else . end)
    ' "/scan/$OUTPUT_FILE" > "/scan/${OUTPUT_FILE}.tmp" && mv "/scan/${OUTPUT_FILE}.tmp" "/scan/$OUTPUT_FILE"

    VULN_COUNT=$(jq '.runs[0].results | length' "/scan/$OUTPUT_FILE" 2>/dev/null || echo 0)
    echo "✅ Scan complete. Found $VULN_COUNT vulnerability(ies) with severity $SEVERITY or higher."
else
    echo "⚠️ No results file generated."
fi
