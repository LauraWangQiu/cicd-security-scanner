#!/bin/bash
# Check if secrets were found in SARIF results

SARIF_FILE="${1:-results.sarif}"

if [ ! -f "$SARIF_FILE" ]; then
  echo "found=false"
  exit 0
fi

COUNT=$(jq '.runs[0].results | length' "$SARIF_FILE" 2>/dev/null || echo 0)

if [ "$COUNT" -gt 0 ]; then
  echo "found=true"
  echo "count=$COUNT"
else
  echo "found=false"
  echo "count=0"
fi
