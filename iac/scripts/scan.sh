#!/bin/bash
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
FRAMEWORK="${FRAMEWORK:-all}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
SCAN_MODE="${SCAN_MODE:-full}"
BASE_REF="${GITHUB_BASE_REF:-main}"

echo "🔍 Running Checkov IaC scan..."
echo "   Mode: $SCAN_MODE"

git config --global --add safe.directory "$SCAN_PATH"
cd "$SCAN_PATH"

# IaC file patterns
IAC_PATTERNS="*.tf *.tfvars *.yml *.yaml Dockerfile docker-compose* *.json"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning only changed IaC files..."
    git fetch origin "$BASE_REF" --depth=1 2>/dev/null || true
    CHANGED_FILES=$(git diff --name-only --diff-filter=AMRC "origin/$BASE_REF"...HEAD -- $IAC_PATTERNS 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo "[*] No IaC files changed — generating empty SARIF"
        echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Checkov","rules":[]}},"results":[]}]}' > /scan/results.sarif
    else
        echo "[*] Changed IaC files:"
        echo "$CHANGED_FILES"
        # Build --file args for checkov
        FILE_ARGS=""
        for f in $CHANGED_FILES; do
            [ -f "$f" ] && FILE_ARGS="$FILE_ARGS --file $f"
        done

        if [ -z "$FILE_ARGS" ]; then
            echo "[*] No scannable IaC files in diff — generating empty SARIF"
            echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Checkov","rules":[]}},"results":[]}]}' > /scan/results.sarif
        else
            echo "[*] Scanning $(echo $CHANGED_FILES | wc -w) changed IaC file(s)..."
            checkov \
                $FILE_ARGS \
                --framework "$FRAMEWORK" \
                --output sarif \
                --output-file-path /scan \
                --soft-fail || true
        fi
    fi
else
    # Full scan mode
    checkov \
        -d "$SCAN_PATH" \
        --framework "$FRAMEWORK" \
        --output sarif \
        --output-file-path /scan \
        --soft-fail || true
fi

# Rename output file
if [ -f /scan/results_sarif.sarif ]; then
    mv /scan/results_sarif.sarif /scan/results.sarif
fi

# Format output, fix /scan/ paths
if [ -f /scan/results.sarif ]; then
    jq --indent 2 '
      walk(if type == "string" then gsub("^/scan/"; "") else . end)
    ' /scan/results.sarif > /scan/results.sarif.tmp && mv /scan/results.sarif.tmp /scan/results.sarif

    TOTAL=$(jq '.runs[0].results | length' /scan/results.sarif 2>/dev/null || echo "0")
    echo ""
    echo "📊 IaC Results Summary:"
    echo "   Total findings: $TOTAL"
fi

echo "✅ IaC scan complete. Results in /scan/results.sarif"

# Populate SARIF 'artifacts' so GitHub shows scanned files in the UI
if [ -f /scan/results.sarif ]; then
    jq '
        if .runs and .runs[0] then
            .runs[0].artifacts = (
                [ .runs[0].results[]?.locations[]?.physicalLocation?.artifactLocation?.uri ]
                | map(select(. != null))
                | map( gsub("^/scan/"; "") )
                | unique
                | map({ location: { uri: . } })
            )
        else
            .
        end
    ' /scan/results.sarif > /scan/results.sarif.tmp && mv /scan/results.sarif.tmp /scan/results.sarif || true
fi
