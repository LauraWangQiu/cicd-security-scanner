#!/bin/bash
# ──────────────────────────────────────────────────────────────
#  Check SARIF results — shared by all action.yaml files
#  Outputs: found=true|false, count=N
# ──────────────────────────────────────────────────────────────
SARIF_FILE="${1:-results.sarif}"

if [ ! -f "$SARIF_FILE" ]; then
    echo "found=false"
    echo "count=0"
    exit 0
fi

COUNT=$(jq '[.runs[].results[]] | length' "$SARIF_FILE" 2>/dev/null || echo 0)

if [ "$COUNT" -gt 0 ]; then
    echo "found=true"
    echo "count=$COUNT"
else
    echo "found=false"
    echo "count=0"
fi
