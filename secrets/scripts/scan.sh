#!/bin/bash
set -e

# ──────────────────────────────────────────────────────────────
#  Secret Scanner Dispatcher
#  Selects the scanning tool based on the TOOL environment variable.
#  Supported tools: gitleaks (default), trufflehog
#  To add a new tool, create scripts/scan-<toolname>.sh and add
#  it to the case below and the Dockerfile.
# ──────────────────────────────────────────────────────────────

TOOL="${TOOL:-gitleaks}"
TARGET=/scan
LEAKS_FILE="results.sarif"

# SCAN_MODE options:
#   - "pr"      : Scan only files changed in PR (CI mode, requires GITHUB_BASE_REF)
#   - "history" : Scan entire git history (all commits)
#   - "files"   : Scan current files on disk (default for local)
SCAN_MODE=${SCAN_MODE:-"auto"}

git config --global --add safe.directory "$TARGET"
cd "$TARGET"

# Auto-detect mode if not explicitly set
if [ "$SCAN_MODE" = "auto" ]; then
    if [ -n "$GITHUB_BASE_REF" ] && git remote get-url origin &>/dev/null; then
        SCAN_MODE="pr"
    else
        SCAN_MODE="files"
    fi
fi

export SCAN_MODE
export LEAKS_FILE

echo "🔐 Secret Scanner"
echo "   Tool: $TOOL"
echo "   Mode: $SCAN_MODE"

SCRIPT_DIR="/scripts"

# Dispatch to tool-specific script
case "$TOOL" in
    gitleaks)
        source "$SCRIPT_DIR/scan-gitleaks.sh"
        ;;
    trufflehog)
        source "$SCRIPT_DIR/scan-trufflehog.sh"
        ;;
    *)
        echo "[!] Unknown TOOL: $TOOL"
        echo "    Supported tools: gitleaks, trufflehog"
        echo ""
        echo "    To add a new tool:"
        echo "      1. Create scripts/scan-<toolname>.sh"
        echo "      2. Add it to the case in scan.sh"
        echo "      3. Install it in the Dockerfile"
        exit 1
        ;;
esac

echo "[*] Scan complete. Results saved to $LEAKS_FILE"

# Show summary
if [ -f "$LEAKS_FILE" ]; then
    FINDINGS=$(jq '.runs[0].results | length' "$LEAKS_FILE" 2>/dev/null || echo "0")
    echo "[*] Found $FINDINGS potential secret(s)"
    
    # Show details if findings exist
    if [ "$FINDINGS" -gt 0 ]; then
        echo ""
        jq -r '.runs[0].results[] | "  - \(.ruleId): \(.locations[0].physicalLocation.artifactLocation.uri):\(.locations[0].physicalLocation.region.startLine)"' "$LEAKS_FILE" 2>/dev/null || true
    fi
fi
