#!/bin/bash
# Trivy — container image scanner
# Called by scan.sh dispatcher — do not run directly
set -e

TOOL_NAME="Trivy"

# Tool-specific: how to scan a single image
scan_image() {
    local img="$1" outfile="$2"
    # Docker 25+ with the containerd image store exports OCI-layout tars
    # (index.json + blobs/sha256/).  Trivy can read OCI *directories* but NOT
    # OCI tars — it either finds missing dedup'd blobs or fails the "not a
    # directory" stat on index.json.  Fix: docker save → extract to temp dir
    # → scan the directory.
    local tmptar tmpdir
    tmptar=$(mktemp "/tmp/trivy-img-XXXXXX.tar")
    tmpdir=$(mktemp -d "/tmp/trivy-img-XXXXXX")
    if ! docker save "$img" -o "$tmptar" 2>/dev/null; then
        echo "[!] docker save failed for $img — falling back to daemon scan"
        rm -f "$tmptar"; rm -rf "$tmpdir"
        trivy image --severity "$SEVERITY" --format sarif --output "$outfile" "$img" || true
        return
    fi
    if ! tar -xf "$tmptar" -C "$tmpdir" 2>/dev/null; then
        echo "[!] tar extract failed — falling back to scanning the tar directly"
        rm -rf "$tmpdir"
        trivy image --input "$tmptar" --severity "$SEVERITY" --format sarif --output "$outfile" || true
        rm -f "$tmptar"
        return
    fi
    rm -f "$tmptar"
    trivy image --input "$tmpdir" --severity "$SEVERITY" --format sarif --output "$outfile" || true
    rm -rf "$tmpdir"
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
