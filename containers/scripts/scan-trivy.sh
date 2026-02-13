#!/bin/bash
# ──────────────────────────────────────────────────────────────
#  Trivy container scanner
#  Called by scan.sh dispatcher — do not run directly
# ──────────────────────────────────────────────────────────────
set -e

TOOL_NAME="Trivy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

SCAN_PATH="${SCAN_PATH:-/scan}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
IMAGE="${IMAGE:-}"

cd "$SCAN_PATH"
echo "[*] Tool: Trivy"

# ── Scan a single image, write SARIF to the given path ───────
scan_image() {
    local img="$1" outfile="$2"
    trivy image \
        --severity "$SEVERITY" \
        --format sarif \
        --output "$outfile" \
        "$img" || true
}

# ── Build images → scan each → merge SARIF ───────────────────
scan_built_images() {
    local TMP_DIR="/tmp/trivy-sarif"
    mkdir -p "$TMP_DIR"

    local j=0 PARTS=()
    for img in "${BUILT_IMAGES[@]}"; do
        j=$((j+1))
        local part="$TMP_DIR/part-${j}.sarif"
        echo "[*] Scanning $img -> $part"
        scan_image "$img" "$part"
        [ -f "$part" ] && PARTS+=("$part")
    done

    merge_sarif /scan/results.sarif "${PARTS[@]}"
    print_summary /scan/results.sarif
    cleanup_images
    rm -rf "$TMP_DIR"
}

# ──────────────────────────────────────────────────────────────
#  Main logic
# ──────────────────────────────────────────────────────────────
if [ -n "$IMAGE" ]; then
    echo "[*] Scanning explicit image: $IMAGE"
    scan_image "$IMAGE" /scan/results.sarif

elif discover_dockerfiles; then
    build_images "${DOCKERFILES[@]}"
    if [ ${#BUILT_IMAGES[@]} -eq 0 ]; then
        echo "[!] No images built successfully"
        write_empty_sarif "$TOOL_NAME" /scan/results.sarif
    else
        scan_built_images
    fi

else
    echo "[!] No Dockerfiles found — scanning filesystem for misconfigurations..."
    trivy config \
        --severity "$SEVERITY" \
        --format sarif \
        --output /scan/results.sarif \
        "$SCAN_PATH" || true
fi

# Ensure SARIF always exists
[ -f /scan/results.sarif ] || write_empty_sarif "$TOOL_NAME" /scan/results.sarif
