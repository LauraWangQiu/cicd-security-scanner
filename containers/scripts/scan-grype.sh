#!/bin/bash
# Grype — container image scanner
# Called by scan.sh dispatcher — do not run directly
set -e

TOOL_NAME="Grype"

# Tool-specific: how to scan a single image
scan_image() {
    local img="$1" outfile="$2"
    grype "$img" -o sarif --file "$outfile" 2>/dev/null || true
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
    echo "[*] No Dockerfiles — scanning filesystem..."
    grype "dir:$SCAN_PATH" -o sarif --file "$RESULTS_FILE" 2>/dev/null || true
fi
