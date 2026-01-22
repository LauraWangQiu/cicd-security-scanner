#!/bin/bash
set -e

TARGET=/scan
OUT=/scan/reports

mkdir -p "$OUT"

# 🔐 Fix Git safe directory issue (CI environments)
git config --global --add safe.directory "$TARGET"

echo "[*] Running Gitleaks on $TARGET..."
gitleaks detect \
  --source "$TARGET" \
  --report-format json \
  --report-path "$OUT/gitleaks.json" \
  --redact || true

COUNT=$(jq 'length' "$OUT/gitleaks.json")

if [ "$COUNT" -gt 0 ]; then
  echo "[!] Secrets found: $COUNT"
  exit 1
fi

echo "[+] No secrets found"
