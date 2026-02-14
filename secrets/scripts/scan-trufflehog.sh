#!/bin/bash
# TruffleHog — secret scanner
# Called by scan.sh dispatcher — do not run directly
set -e

TOOL_NAME="TruffleHog"
TRUFFLEHOG_JSON="/tmp/trufflehog_results.json"

case "$SCAN_MODE" in
    pr)
        echo "[*] PR mode: scanning filesystem..."
        trufflehog filesystem . --json --no-update 2>/dev/null > "$TRUFFLEHOG_JSON" || true
        ;;
    history)
        echo "[*] Scanning git history..."
        REMOTE_URL=""
        if [ -n "${TRUFFLEHOG_REMOTE_URL:-}" ]; then
            REMOTE_URL="$TRUFFLEHOG_REMOTE_URL"
        elif [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
            REMOTE_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
        else
            echo "[!] No credentials for remote history scan — skipping"
            write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"
        fi
        if [ -n "$REMOTE_URL" ]; then
            echo "[*] Remote: $REMOTE_URL"
            trufflehog git "$REMOTE_URL" --json --no-update 2>/dev/null > "$TRUFFLEHOG_JSON" || true
        fi
        ;;
    files|*)
        echo "[*] Scanning current files..."
        trufflehog filesystem . --json --no-update 2>/dev/null > "$TRUFFLEHOG_JSON" || true
        ;;
esac

# Convert TruffleHog JSON → SARIF
if [ -f "$TRUFFLEHOG_JSON" ] && [ -s "$TRUFFLEHOG_JSON" ]; then
    echo "[*] Converting results to SARIF..."
    jq -s '{
      "version": "2.1.0",
      "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json",
      "runs": [{
        "tool": { "driver": { "name": "TruffleHog", "informationUri": "https://github.com/trufflesecurity/trufflehog", "rules": [] }},
        "results": [.[] | {
          "ruleId": (.DetectorName // "secret"),
          "level": (if .Verified then "error" else "warning" end),
          "message": { "text": ("Secret: " + (.DetectorName // "unknown") + (if .Verified then " (verified)" else " (unverified)" end)) },
          "locations": [{ "physicalLocation": {
            "artifactLocation": { "uri": (.SourceMetadata.Data.Filesystem.file // .SourceMetadata.Data.Git.file // "unknown") },
            "region": { "startLine": (.SourceMetadata.Data.Filesystem.line // .SourceMetadata.Data.Git.line // 1) }
          }}]
        }]
      }]
    }' "$TRUFFLEHOG_JSON" > "$RESULTS_FILE"
fi

rm -f "$TRUFFLEHOG_JSON"
