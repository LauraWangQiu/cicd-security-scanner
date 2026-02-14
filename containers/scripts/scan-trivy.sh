#!/bin/bash
# Trivy — container image scanner
# Called by scan.sh dispatcher — do not run directly
set -e

TOOL_NAME="Trivy"

# Tool-specific: how to scan a single image
scan_image() {
    local img="$1" outfile="$2"
    # Save the image to a tar and scan the tar with Trivy's --input option.
    # This avoids issues where Trivy extracts a temporary docker image tar and
    # finds missing blobs when the daemon/BuildKit produced a layout that
    # doesn't match the temporary tar content.
    local tmp
    tmp=$(mktemp -u "/tmp/scan-XXXXXX.tar")
    docker save "$img" -o "$tmp" 2>/dev/null || { echo "[!] docker save failed for $img"; return; }
    trivy image --input "$tmp" --severity "$SEVERITY" --format sarif --output "$outfile" || true
    rm -f "$tmp"
}

# ── Main logic ───────────────────────────────────────────────
if [ -n "$IMAGE" ]; then
    echo "[*] Scanning explicit image: $IMAGE"
    scan_image "$IMAGE" "$RESULTS_FILE"

elif discover_dockerfiles; then
    build_images "${DOCKERFILES[@]}"
    [ ${#BUILT_IMAGES[@]} -gt 0 ] && scan_built_images \
        || write_empty_sarif "$TOOL_NAME" "$RESULTS_FILE"

else
    echo "[*] No Dockerfiles — scanning for misconfigurations..."
    trivy config --severity "$SEVERITY" \
        --format sarif --output "$RESULTS_FILE" "$SCAN_PATH" || true
fi
