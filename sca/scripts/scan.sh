#!/bin/bash
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
OUTPUT_FILE="${OUTPUT_FILE:-results.sarif}"
SCAN_MODE="${SCAN_MODE:-full}"
BASE_REF="${GITHUB_BASE_REF:-main}"

echo "🔍 Starting SCA scan with Trivy..."
echo "   Path: $SCAN_PATH"
echo "   Severity: $SEVERITY"
git config --global --add safe.directory "$SCAN_PATH"
cd "$SCAN_PATH"

# Dependency file patterns
DEP_PATTERNS="requirements*.txt Pipfile* poetry.lock pyproject.toml package.json package-lock.json yarn.lock pnpm-lock.yaml go.sum go.mod Gemfile.lock Cargo.lock composer.lock *.csproj *.sln"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning only changed dependency files..."
    git fetch origin "$BASE_REF" --depth=1 2>/dev/null || true
    CHANGED_FILES=$(git diff --name-only --diff-filter=AMRC "origin/$BASE_REF"...HEAD -- $DEP_PATTERNS 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo "[*] No dependency files changed — generating empty SARIF"
        echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Trivy","rules":[]}},"results":[]}]}' > "/scan/$OUTPUT_FILE"
    else
        echo "[*] Changed dependency files:"
        echo "$CHANGED_FILES"
        
        # Copy changed files to temp dir preserving structure, then run trivy ONCE
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
            echo "[*] No scannable dependency files in diff — generating empty SARIF"
            echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Trivy","rules":[]}},"results":[]}]}' > "/scan/$OUTPUT_FILE"
        else
            echo "[*] Scanning $FILE_COUNT dependency file(s) in single trivy run..."
            trivy filesystem "$TMP_DIR" \
                --scanners vuln \
                --severity "$SEVERITY" \
                --format sarif \
                --output "/scan/$OUTPUT_FILE" \
                --exit-code 0 || true
        fi
        rm -rf "$TMP_DIR"
    fi
else
    # Full scan mode
    trivy filesystem "$SCAN_PATH" \
        --scanners vuln \
        --severity "$SEVERITY" \
        --format sarif \
        --output "/scan/$OUTPUT_FILE" \
        --exit-code 0
fi

# Format output, fix paths (remove /scan/ and temp dir prefixes)
if [ -f "/scan/$OUTPUT_FILE" ]; then
    jq --indent 2 '
      walk(if type == "string" then gsub("^/scan/"; "") | gsub("^/tmp/sca_scan_[0-9]+/"; "") else . end)
    ' "/scan/$OUTPUT_FILE" > "/scan/${OUTPUT_FILE}.tmp" && mv "/scan/${OUTPUT_FILE}.tmp" "/scan/$OUTPUT_FILE"

    VULN_COUNT=$(jq '.runs[0].results | length' "/scan/$OUTPUT_FILE" 2>/dev/null || echo 0)
    echo "✅ Scan complete. Found $VULN_COUNT vulnerability(ies) with severity $SEVERITY or higher."
else
    echo "⚠️ No results file generated."
fi
