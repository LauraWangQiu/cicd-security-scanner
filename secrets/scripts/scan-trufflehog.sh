#!/bin/bash
# TruffleHog secret scanner
# Called by scan.sh dispatcher — do not run directly
set -e

TARGET=/scan
LEAKS_FILE="results.sarif"

cd "$TARGET"

echo "[*] Tool: TruffleHog"

# TruffleHog outputs JSON; we convert to SARIF for compatibility
TRUFFLEHOG_JSON="/tmp/trufflehog_results.json"

case "$SCAN_MODE" in
    pr)
        echo "[*] Scanning changed files in PR..."
        BASE_REF=${GITHUB_BASE_REF:-main}

        DIFF_FILES=$(git diff --name-only --diff-filter=AMRC origin/$BASE_REF...HEAD 2>/dev/null || true)

        if [ -z "$DIFF_FILES" ]; then
            echo "[*] No files to scan"
            echo '{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"trufflehog"}},"results":[]}]}' > "$LEAKS_FILE"
        else
            echo "[*] Scanning changed files..."
            # TruffleHog scans the filesystem; we use --only-verified for fewer FPs
            trufflehog filesystem . \
                --json \
                --no-update \
                2>/dev/null > "$TRUFFLEHOG_JSON" || true
        fi
        ;;

    history)
        echo "[*] Scanning entire git history..."
        trufflehog git file://. \
            --json \
            --no-update \
            2>/dev/null > "$TRUFFLEHOG_JSON" || true
        ;;

    files)
        echo "[*] Scanning current files on disk..."
        trufflehog filesystem . \
            --json \
            --no-update \
            2>/dev/null > "$TRUFFLEHOG_JSON" || true
        ;;
esac

# Convert TruffleHog JSON to SARIF format
if [ -f "$TRUFFLEHOG_JSON" ] && [ -s "$TRUFFLEHOG_JSON" ]; then
    echo "[*] Converting TruffleHog results to SARIF..."
    jq -s '
    {
      "version": "2.1.0",
      "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json",
      "runs": [{
        "tool": {
          "driver": {
            "name": "trufflehog",
            "informationUri": "https://github.com/trufflesecurity/trufflehog",
            "rules": []
          }
        },
        "results": [.[] | {
          "ruleId": (.DetectorName // .SourceMetadata.Data.Filesystem.file // "secret"),
          "level": (if .Verified then "error" else "warning" end),
          "message": {
            "text": ("Secret detected by TruffleHog: " + (.DetectorName // "unknown") + (if .Verified then " (verified)" else " (unverified)" end))
          },
          "locations": [{
            "physicalLocation": {
              "artifactLocation": {
                "uri": (.SourceMetadata.Data.Filesystem.file // .SourceMetadata.Data.Git.file // "unknown")
              },
              "region": {
                "startLine": (.SourceMetadata.Data.Filesystem.line // .SourceMetadata.Data.Git.line // 1)
              }
            }
          }]
        }]
      }]
    }
    ' "$TRUFFLEHOG_JSON" > "$LEAKS_FILE"
else
    # No findings or no JSON output
    if [ ! -f "$LEAKS_FILE" ]; then
        echo '{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"trufflehog"}},"results":[]}]}' > "$LEAKS_FILE"
    fi
fi

rm -f "$TRUFFLEHOG_JSON"
