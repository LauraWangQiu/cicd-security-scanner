#!/bin/bash
set -e
# ──────────────────────────────────────────────────────────────
#  SAST Scanner — Dispatcher
#  Tools: semgrep (default), bandit
# ──────────────────────────────────────────────────────────────

TOOL="${TOOL:-semgrep}"
SCAN_PATH="${SCAN_PATH:-/scan}"
SCAN_MODE="${SCAN_MODE:-full}"
BASE_REF="${GITHUB_BASE_REF:-main}"
SEVERITY="${SEVERITY:-ERROR,WARNING}"
RESULTS_FILE="/scan/results.sarif"
SCRIPT_DIR="/scripts"

source "$SCRIPT_DIR/helpers.sh"

git config --global --add safe.directory "$SCAN_PATH"
cd "$SCAN_PATH"

export SCAN_MODE BASE_REF SCAN_PATH SEVERITY RESULTS_FILE

echo "🔍 SAST Scanner"
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

# Post-process: remove cross-scanner duplicates (secrets/IaC/containers)
if [ -f "$RESULTS_FILE" ]; then
    jq --indent 2 '
      .runs[].results |= [.[] | select(
        (.ruleId | test("secrets") | not) and
        (.ruleId | test("^yaml\\.(docker-compose|kubernetes)\\.") | not) and
        (.ruleId | test("^terraform\\.") | not)
      )]
    ' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
fi

ensure_sarif "${TOOL_NAME:-$TOOL}" "$RESULTS_FILE"
fix_sarif_paths "$RESULTS_FILE"
print_findings "$RESULTS_FILE"
echo "✅ Scan complete"
