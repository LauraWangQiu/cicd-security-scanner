#!/bin/bash
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-ERROR,WARNING}"
CONFIG="${SEMGREP_CONFIG:-auto}"
SCAN_MODE="${SCAN_MODE:-full}"
BASE_REF="${GITHUB_BASE_REF:-main}"

echo "🔍 Running Semgrep SAST scan..."
git config --global --add safe.directory "$SCAN_PATH"
cd "$SCAN_PATH"

if [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning only changed files..."
    git fetch origin "$BASE_REF" --depth=1 2>/dev/null || true
    CHANGED_FILES=$(git diff --name-only --diff-filter=AMRC "origin/$BASE_REF"...HEAD 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        echo "[*] No changed files detected — generating empty SARIF"
        echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Semgrep","rules":[]}},"results":[]}]}' > /scan/results.sarif
    else
        # Filter to files that exist on disk
        FILE_ARGS=""
        for f in $CHANGED_FILES; do
            [ -f "$f" ] && FILE_ARGS="$FILE_ARGS $f"
        done

        if [ -z "$FILE_ARGS" ]; then
            echo "[*] No scannable files in diff — generating empty SARIF"
            echo '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Semgrep","rules":[]}},"results":[]}]}' > /scan/results.sarif
        else
            echo "[*] Scanning $(echo $FILE_ARGS | wc -w) changed file(s)..."
            semgrep \
                --config "$CONFIG" \
                --sarif \
                --no-git-ignore \
                --output /scan/results.sarif \
                $FILE_ARGS || true
        fi
    fi
else
    # Full scan mode
    semgrep \
        --config "$CONFIG" \
        --sarif \
        --no-git-ignore \
        --output /scan/results.sarif \
        "$SCAN_PATH" || true
fi

# Post-process SARIF: fix paths, remove duplicates with other scanners
if [ -f /scan/results.sarif ]; then
    jq --indent 2 '
      # Remove results handled by dedicated scanners (secrets, IaC, containers)
      .runs[].results |= [.[] | select(
        (.ruleId | test("secrets") | not) and
        (.ruleId | test("^yaml\\.docker-compose\\.") | not) and
        (.ruleId | test("^yaml\\.kubernetes\\.") | not) and
        (.ruleId | test("^terraform\\.") | not)
      )] |
      # Fix /scan/ paths to relative paths
      walk(if type == "string" then gsub("^/scan/"; "") else . end)
    ' /scan/results.sarif > /scan/results.sarif.tmp && mv /scan/results.sarif.tmp /scan/results.sarif
    
    # Count findings from SARIF
    TOTAL=$(jq '.runs[0].results | length' /scan/results.sarif 2>/dev/null || echo "0")
    
    echo ""
    echo "📊 SAST Results Summary:"
    echo "   Total findings: $TOTAL"
fi

echo "✅ SAST scan complete. Results in /scan/results.sarif"

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
