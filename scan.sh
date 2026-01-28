#!/bin/bash
set -e

TARGET=/scan
DIFF_FILES="pr.diff"
LEAKS_FILE="results.sarif"
TMP_DIR="sarif_parts"

BASE_REF=${GITHUB_BASE_REF:-main}

git config --global --add safe.directory "$TARGET"
cd "$TARGET"

git diff --name-only --diff-filter=AMRC origin/$BASE_REF...HEAD > "$DIFF_FILES" || true

mkdir -p "$TMP_DIR"
rm -f "$TMP_DIR"/*.sarif

echo "[*] Running Gitleaks per changed file..."

i=0
while IFS= read -r path; do
  # saltar líneas vacías
  [ -z "$path" ] && continue

  # saltar si el fichero ya no existe (renames/deletes raros)
  [ ! -f "$path" ] && continue

  part="$TMP_DIR/part_$i.sarif"

  echo "  -> Scanning $path"
  gitleaks dir "$path" \
    --report-format sarif \
    --report-path "$part" \
    --redact || true

  i=$((i+1))
done < "$DIFF_FILES"

echo "[*] Merging SARIF files..."

# Crear SARIF final válido combinando results
jq -s '
{
  "version": "2.1.0",
  "runs": [
    {
      "tool": (.[0].runs[0].tool),
      "results": (map(.runs[0].results) | add)
    }
  ]
}
' "$TMP_DIR"/*.sarif > "$LEAKS_FILE"
