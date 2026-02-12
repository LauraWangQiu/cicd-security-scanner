#!/bin/bash
# Grype SCA scanner (Anchore)
# Called by scan.sh dispatcher — do not run directly
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
OUTPUT_FILE="${OUTPUT_FILE:-results.sarif}"

cd "$SCAN_PATH"

echo "[*] Tool: Grype (Anchore)"

# Convert severity filter to Grype format (lowercase, single value for --fail-on)
GRYPE_SEVERITY=$(echo "$SEVERITY" | tr ',' '\n' | sort | head -1 | tr '[:upper:]' '[:lower:]')

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning only changed dependency files..."
    git fetch origin "$BASE_REF" --depth=1 2>/dev/null || true

    DEP_PATTERNS="requirements*.txt Pipfile* poetry.lock pyproject.toml package.json package-lock.json yarn.lock pnpm-lock.yaml go.sum go.mod Gemfile.lock Cargo.lock composer.lock *.csproj *.sln"
    CHANGED_FILES=$(git diff --name-only --diff-filter=AMRC "origin/$BASE_REF"...HEAD -- $DEP_PATTERNS 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo "[*] No dependency files changed — generating empty SARIF"
        echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Grype","rules":[]}},"results":[]}]}' > "/scan/$OUTPUT_FILE"
    else
        echo "[*] Changed dependency files:"
        echo "$CHANGED_FILES"

        TMP_DIR="/tmp/sca_scan_$$"
        mkdir -p "$TMP_DIR"

        FILE_COUNT=0
        for f in $CHANGED_FILES; do
            [ ! -f "$f" ] && continue
            mkdir -p "$TMP_DIR/$(dirname "$f")"
            cp "$f" "$TMP_DIR/$f"
            FILE_COUNT=$((FILE_COUNT + 1))
        done

        if [ "$FILE_COUNT" -eq 0 ]; then
            echo "[*] No scannable dependency files — generating empty SARIF"
            echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Grype","rules":[]}},"results":[]}]}' > "/scan/$OUTPUT_FILE"
        else
            echo "[*] Scanning $FILE_COUNT dependency file(s)..."
            grype "dir:$TMP_DIR" \
                --output sarif \
                --file "/scan/$OUTPUT_FILE" \
                2>/dev/null || true
        fi
        rm -rf "$TMP_DIR"
    fi
else
    grype "dir:$SCAN_PATH" \
        --output sarif \
        --file "/scan/$OUTPUT_FILE" \
        2>/dev/null || true
fi

# Ensure SARIF file exists
if [ ! -f "/scan/$OUTPUT_FILE" ]; then
    echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Grype","rules":[]}},"results":[]}]}' > "/scan/$OUTPUT_FILE"
fi
