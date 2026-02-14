#!/bin/bash
# Trivy — container image scanner
# Called by scan.sh dispatcher — do not run directly
set -e

TOOL_NAME="Trivy"

# Tool-specific: how to scan a single image.
# $1 can be a rootfs directory (fallback), a tar file (buildx), or an image name/tag.
scan_image() {
    local img="$1" outfile="$2"
    if [ -d "$img" ]; then
        # Extracted root filesystem (fallback: docker export + tar -x)
        trivy rootfs --severity "$SEVERITY" \
            --format sarif --output "$outfile" "$img" || true
    elif [ -f "$img" ]; then
        # Tar file (from buildx --output type=docker,dest=<file>)
        trivy image --input "$img" --severity "$SEVERITY" \
            --format sarif --output "$outfile" || true
    else
        # Image name/tag — scan from daemon
        trivy image --severity "$SEVERITY" \
            --format sarif --output "$outfile" "$img" || true
    fi
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
