#!/bin/bash
set -e
# ──────────────────────────────────────────────────────────────
#  SCA Scanner — Dispatcher
#  Tools: trivy (default), grype
# ──────────────────────────────────────────────────────────────

TOOL="${TOOL:-trivy}"
SCAN_PATH="${SCAN_PATH:-/scan}"
SCAN_MODE="${SCAN_MODE:-full}"
BASE_REF="${GITHUB_BASE_REF:-main}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
RESULTS_FILE="/scan/results.sarif"
SCRIPT_DIR="/scripts"

source "$SCRIPT_DIR/helpers.sh"

git config --global --add safe.directory "$SCAN_PATH"
cd "$SCAN_PATH"

export SCAN_MODE BASE_REF SCAN_PATH SEVERITY RESULTS_FILE

echo "📦 SCA Scanner"
echo "   Tool: $TOOL | Mode: $SCAN_MODE"

# Auto-dispatch
TOOL_SCRIPT="$SCRIPT_DIR/scan-${TOOL}.sh"
if [ ! -f "$TOOL_SCRIPT" ]; then
    echo "[!] Unknown tool: $TOOL"
    echo "    Available:"
    for s in "$SCRIPT_DIR"/scan-*.sh; do
        echo "      - $(basename "$s" | sed 's/^scan-//; s/\.sh$//')"
    done
    exit 1
fi

source "$TOOL_SCRIPT"

# Post-process
ensure_sarif "${TOOL_NAME:-$TOOL}" "$RESULTS_FILE"
fix_sarif_paths "$RESULTS_FILE"
print_findings "$RESULTS_FILE"
echo "✅ Scan complete"
