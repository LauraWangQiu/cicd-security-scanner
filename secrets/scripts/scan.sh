#!/bin/bash
set -e

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

echo "[*] Scan mode: $SCAN_MODE"

case "$SCAN_MODE" in
    pr)
        # CI mode: scan only changed files in PR
        echo "[*] Scanning changed files in PR..."
        BASE_REF=${GITHUB_BASE_REF:-main}
        
        DIFF_FILES="pr.diff"
        TMP_DIR="sarif_parts"
        
        git diff --name-only --diff-filter=AMRC origin/$BASE_REF...HEAD > "$DIFF_FILES" || true
        
        mkdir -p "$TMP_DIR"
        rm -f "$TMP_DIR"/*.sarif
        
        echo "[*] Running Gitleaks per changed file..."
        
        i=0
        while IFS= read -r path; do
            [ -z "$path" ] && continue
            [ ! -f "$path" ] && continue
            
            part="$TMP_DIR/part_$i.sarif"
            echo "  -> Scanning $path"
            gitleaks dir "$path" \
                --report-format sarif \
                --report-path "$part" \
                --redact || true
            i=$((i+1))
        done < "$DIFF_FILES"
        
        # Merge SARIF files if any exist
        if ls "$TMP_DIR"/*.sarif 1>/dev/null 2>&1; then
            echo "[*] Merging SARIF files..."
            jq -s '
            {
              "version": "2.1.0",
              "runs": [
                {
                  "tool": (.[0].runs[0].tool),
                  "results": (map(.runs[0].results) | add // [])
                }
              ]
            }
            ' "$TMP_DIR"/*.sarif > "$LEAKS_FILE"
        else
            echo "[*] No files to scan"
            echo '{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"gitleaks"}},"results":[]}]}' > "$LEAKS_FILE"
        fi
        ;;
        
    history)
        # Scan entire git history (all commits)
        echo "[*] Scanning entire git history..."
        gitleaks detect --source="." \
            --report-format sarif \
            --report-path "$LEAKS_FILE" \
            --redact || true
        ;;
        
    files)
        # Scan current files on disk (includes uncommitted changes)
        echo "[*] Scanning current files on disk..."
        gitleaks dir . \
            --report-format sarif \
            --report-path "$LEAKS_FILE" \
            --redact || true
        ;;
        
    *)
        echo "[!] Unknown SCAN_MODE: $SCAN_MODE"
        echo "    Valid options: pr, history, files"
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
