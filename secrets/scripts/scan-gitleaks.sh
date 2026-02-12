#!/bin/bash
# Gitleaks secret scanner
# Called by scan.sh dispatcher — do not run directly
set -e

TARGET=/scan
LEAKS_FILE="results.sarif"

cd "$TARGET"

echo "[*] Tool: Gitleaks"

case "$SCAN_MODE" in
    pr)
        echo "[*] Scanning changed files in PR..."
        BASE_REF=${GITHUB_BASE_REF:-main}
        DIFF_FILES="pr.diff"
        TMP_DIR="secret_parts"

        git diff --name-only --diff-filter=AMRC origin/$BASE_REF...HEAD > "$DIFF_FILES" || true
        mkdir -p "$TMP_DIR"
        rm -f "$TMP_DIR"/*.sarif

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
        echo "[*] Scanning entire git history..."
        gitleaks detect --source="." \
            --report-format sarif \
            --report-path "$LEAKS_FILE" \
            --redact || true
        ;;

    files)
        echo "[*] Scanning current files on disk..."
        gitleaks dir . \
            --report-format sarif \
            --report-path "$LEAKS_FILE" \
            --redact || true
        ;;
esac
