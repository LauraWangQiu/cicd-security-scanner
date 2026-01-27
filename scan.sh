#!/bin/bash
set -e

TARGET=/scan
OUT=/scan/reports
DIFF_FILE_PATH="$OUT/pr.diff"
LEAKS_FILE_PATH="$OUT/gitleaks.json"

mkdir -p "$OUT"

BASE_REF=${GITHUB_BASE_REF:-main}

git config --global --add safe.directory "$TARGET"
cd "$TARGET"

git diff origin/$BASE_REF...HEAD > "$DIFF_FILE_PATH" 2>/dev/null || \
git diff HEAD~1...HEAD > "$DIFF_FILE_PATH" || \
git diff --cached > "$DIFF_FILE_PATH" || true

echo "[*] Running Gitleaks on $TARGET..."
gitleaks detect \
  --source "$DIFF_FILE_PATH" \
  --no-git \
  --report-format json \
  --report-path "$LEAKS_FILE_PATH" \
  --redact || true
