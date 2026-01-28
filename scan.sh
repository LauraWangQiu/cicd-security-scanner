#!/bin/bash
set -e

TARGET=/scan
DIFF_FILE_PATH="pr.diff"
LEAKS_FILE_PATH="results.sarif"

BASE_REF=${GITHUB_BASE_REF:-main}

git config --global --add safe.directory "$TARGET"
cd "$TARGET"

git diff origin/$BASE_REF...HEAD > "$DIFF_FILE_PATH" 2>/dev/null || true

echo "[*] Running Gitleaks..."
gitleaks detect \
  --source "$DIFF_FILE_PATH" \
  --no-git \
  --report-format sarif \
  --report-path "$LEAKS_FILE_PATH" \
  --redact || true
