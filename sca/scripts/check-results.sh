#!/bin/bash
# Check if vulnerabilities were found in SARIF results

SARIF_FILE="${1:-results.sarif}"

if [ ! -f "$SARIF_FILE" ]; then
  echo "found=false"
  echo "count=0"
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
