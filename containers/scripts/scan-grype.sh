#!/bin/bash
# Grype container scanner (Anchore)
# Called by scan.sh dispatcher — do not run directly
set -e

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
IMAGE="${IMAGE:-}"

cd "$SCAN_PATH"

echo "[*] Tool: Grype (Anchore)"

EMPTY_SARIF='{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"Grype","rules":[]}},"results":[]}]}'

# ── Helper: merge multiple SARIF files into one ──────────────
merge_sarif() {
    local outfile="$1"; shift
    local parts=("$@")
    if [ ${#parts[@]} -eq 0 ]; then
        echo "$EMPTY_SARIF" > "$outfile"; return
    fi
    if [ ${#parts[@]} -eq 1 ]; then
        cp "${parts[0]}" "$outfile"; return
    fi
    jq -s '{
        "version": "2.1.0",
        "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json",
        "runs": [.[].runs[]]
    }' "${parts[@]}" > "$outfile"
}

# ── Helper: build images from Dockerfiles, scan each, merge ──
build_and_scan() {
    local dockerfiles=("$@")
    local TMP_DIR="/tmp/grype-sarif"
    mkdir -p "$TMP_DIR"

    local i=0 IMAGES=()
    for df in "${dockerfiles[@]}"; do
        [ ! -f "$df" ] && continue
        i=$((i+1))
        local tag="grype-scan:image-${i}"
        local context
        context="$(dirname "$df")"
        [ "$context" = "." ] && context="."

        echo "[*] Building $df (context: $context) -> $tag"
        if docker build -f "$df" -t "$tag" "$context" 2>&1; then
            IMAGES+=("$tag")
        else
            echo "[!] Failed to build $df, skipping..."
        fi
    done

    if [ ${#IMAGES[@]} -eq 0 ]; then
        echo "[!] No images were built successfully"
        echo "$EMPTY_SARIF" > /scan/results.sarif
        rm -rf "$TMP_DIR"; return
    fi

    local j=0 PARTS=()
    for img in "${IMAGES[@]}"; do
        j=$((j+1))
        local part="$TMP_DIR/part-${j}.sarif"
        echo "[*] Scanning $img -> $part"
        grype "$img" -o sarif --file "$part" 2>/dev/null || true
        [ -f "$part" ] && PARTS+=("$part")
        # Clean up the built image
        docker rmi "$img" 2>/dev/null || true
    done

    echo "[*] Merging ${#PARTS[@]} SARIF file(s) into results.sarif..."
    merge_sarif /scan/results.sarif "${PARTS[@]}"

    COUNT=$(jq '[.runs[].results[]] | length' /scan/results.sarif 2>/dev/null || echo "0")
    echo "[*] Total findings across all images: $COUNT"
    rm -rf "$TMP_DIR"
}

# ──────────────────────────────────────────────────────────────
if [ -n "$IMAGE" ]; then
    # Explicit image provided (e.g. nginx:latest)
    echo "Scanning image: $IMAGE"
    grype "$IMAGE" \
        --output sarif \
        --file /scan/results.sarif \
        2>/dev/null || true

elif [ "$SCAN_MODE" = "pr" ]; then
    echo "[*] PR mode: scanning only changed Dockerfiles..."
    git fetch origin "$BASE_REF" --depth=1 2>/dev/null || true
    CHANGED=$(git diff --name-only --diff-filter=AMRC \
        "origin/$BASE_REF"...HEAD -- 'Dockerfile*' '**/Dockerfile*' 2>/dev/null || true)

    if [ -z "$CHANGED" ]; then
        echo "[*] No Dockerfiles changed — generating empty SARIF"
        echo "$EMPTY_SARIF" > /scan/results.sarif
    else
        echo "[*] Changed Dockerfiles:"
        echo "$CHANGED"
        mapfile -t df_list <<< "$CHANGED"
        build_and_scan "${df_list[@]}"
    fi

else
    # Full mode: find all Dockerfiles, build, scan
    echo "[*] Full mode: scanning all Dockerfiles..."
    mapfile -t files < <(git ls-files -- 'Dockerfile*' '**/Dockerfile*' 2>/dev/null || true)
    if [ ${#files[@]} -eq 0 ] || [ -z "${files[0]}" ]; then
        echo "[!] No Dockerfiles found. Scanning filesystem for packages..."
        grype "dir:$SCAN_PATH" \
            --output sarif \
            --file /scan/results.sarif \
            2>/dev/null || true
    else
        echo "[*] Found ${#files[@]} Dockerfile(s)"
        build_and_scan "${files[@]}"
    fi
fi

# Ensure SARIF file exists
if [ ! -f /scan/results.sarif ]; then
    echo "$EMPTY_SARIF" > /scan/results.sarif
fi
