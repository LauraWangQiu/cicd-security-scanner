#!/bin/bash
# Bandit SAST scanner (Python-focused)
# Called by scan.sh dispatcher — do not run directly
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-MEDIUM}"

# Convert severity to Bandit format (lowercase, single value: low, medium, high)
# Input can be "HIGH,CRITICAL" or "MEDIUM" etc.
# Bandit uses: low, medium, high — we pick the lowest specified level
BANDIT_SEVERITY=$(echo "$SEVERITY" | tr ',' '\n' | tr '[:upper:]' '[:lower:]' | \
  sed 's/critical/high/' | \
  sort -t'' -k1,1 | head -1)
# Fallback
BANDIT_SEVERITY=${BANDIT_SEVERITY:-medium}

cd "$SCAN_PATH"

echo "[*] Tool: Bandit (Python SAST)"
echo "   Severity: $BANDIT_SEVERITY (from $SEVERITY)"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning only changed Python files..."
    git fetch origin "$BASE_REF" --depth=1 2>/dev/null || true
    CHANGED_FILES=$(git diff --name-only --diff-filter=AMRC "origin/$BASE_REF"...HEAD -- '*.py' 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo "[*] No Python files changed — generating empty SARIF"
        echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Bandit","rules":[]}},"results":[]}]}' > /scan/results.sarif
        exit 0
    fi

    FILE_ARGS=""
    for f in $CHANGED_FILES; do
        [ -f "$f" ] && FILE_ARGS="$FILE_ARGS $f"
    done

    if [ -z "$FILE_ARGS" ]; then
        echo "[*] No scannable Python files — generating empty SARIF"
        echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Bandit","rules":[]}},"results":[]}]}' > /scan/results.sarif
        exit 0
    fi

    echo "[*] Scanning $(echo $FILE_ARGS | wc -w) changed Python file(s)..."
    bandit $FILE_ARGS \
        -f sarif \
        -o /scan/results.sarif \
        --severity-level "$BANDIT_SEVERITY" \
        -r 2>/dev/null || true
else
    # Full scan: recursively scan all Python files
    PYTHON_FILES=$(find "$SCAN_PATH" -name "*.py" -not -path "*/node_modules/*" -not -path "*/.venv/*" -not -path "*/venv/*" 2>/dev/null || true)

    if [ -z "$PYTHON_FILES" ]; then
        echo "[*] No Python files found — generating empty SARIF"
        echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Bandit","rules":[]}},"results":[]}]}' > /scan/results.sarif
        exit 0
    fi

    bandit -r "$SCAN_PATH" \
        -f sarif \
        -o /scan/results.sarif \
        --severity-level "$BANDIT_SEVERITY" \
        --exclude "*/.venv/*,*/venv/*,*/node_modules/*" \
        2>/dev/null || true
fi

# Ensure SARIF file exists even if bandit found nothing
if [ ! -f /scan/results.sarif ]; then
    echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Bandit","rules":[]}},"results":[]}]}' > /scan/results.sarif
fi
