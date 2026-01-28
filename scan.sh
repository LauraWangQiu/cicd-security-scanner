#!/bin/bash
set -e

TARGET=/scan
DIFF_FILES="pr.diff"
LEAKS_FILE="results.sarif"

BASE_REF=${GITHUB_BASE_REF:-main}

git config --global --add safe.directory "$TARGET"
cd "$TARGET"

git diff --name-only --diff-filter=AMRC origin/$BASE_REF...HEAD > $DIFF_FILES || true

echo '{"runs":[]}' > "$LEAKS_FILE"

echo "[*] Running Gitleaks per file..."

while read -r file; do
  [ -f "$file" ] || continue

  echo "  → scanning $file"

  TMP_SARIF=$(mktemp)

  gitleaks dir "$file" \
    --report-format sarif \
    --report-path "$TMP_SARIF" \
    --redact || true

  jq --slurp '
    .[0].runs += .[1].runs
    | .[0]
  ' "$LEAKS_FILE" "$TMP_SARIF" > "${LEAKS_FILE}.tmp"

  mv "${LEAKS_FILE}.tmp" "$LEAKS_FILE"
  rm "$TMP_SARIF"

done < "$DIFF_FILES"