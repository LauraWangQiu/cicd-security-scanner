#!/bin/bash
set -e
# ──────────────────────────────────────────────────────────────
#  Secret Scanner — Dispatcher
#  Tools: gitleaks (default), trufflehog
# ──────────────────────────────────────────────────────────────

TOOL="${TOOL:-gitleaks}"
SCAN_PATH="${SCAN_PATH:-/scan}"
SCAN_MODE="${SCAN_MODE:-auto}"
BASE_REF="${GITHUB_BASE_REF:-main}"
RESULTS_FILE="/scan/results.sarif"
SCRIPT_DIR="/scripts"

source "$SCRIPT_DIR/helpers.sh"

git config --global --add safe.directory "$SCAN_PATH"
cd "$SCAN_PATH"

# Auto-detect mode
if [ "$SCAN_MODE" = "auto" ]; then
    if [ -n "$GITHUB_BASE_REF" ] && git remote get-url origin &>/dev/null; then
        SCAN_MODE="pr"
    else
        SCAN_MODE="files"
    fi
fi

export SCAN_MODE BASE_REF SCAN_PATH RESULTS_FILE

echo "🔐 Secret Scanner"
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
print_findings "$RESULTS_FILE"
echo "✅ Scan complete"
