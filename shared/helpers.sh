#!/bin/bash
# ──────────────────────────────────────────────────────────────
#  CICD Security Scanner — Shared Helpers
#  Common functions used by ALL scanner modules.
#  Sourced by each module's scan.sh dispatcher.
#
#  Sections:
#    1. SARIF Utilities
#    2. PR Diff Helpers
#    3. Container Helpers (used only by containers module)
# ──────────────────────────────────────────────────────────────

RESULTS_FILE="${RESULTS_FILE:-/scan/results.sarif}"

# ═══════════════════════════════════════════════════════════════
#  1. SARIF Utilities
# ═══════════════════════════════════════════════════════════════

# Print a minimal valid empty SARIF document for a given tool.
empty_sarif() {
    local tool="${1:-Scanner}"
    printf '{"version":"2.1.0","$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"%s","rules":[]}},"results":[]}]}' "$tool"
}

# Write empty SARIF to a file.
write_empty_sarif() { empty_sarif "$1" > "$2"; }

# Create empty SARIF only if the file doesn't already exist.
ensure_sarif() { [ -f "$2" ] || write_empty_sarif "$1" "$2"; }

# Count total findings across all runs.
sarif_count() { jq '[.runs[].results[]] | length' "$1" 2>/dev/null || echo "0"; }

# Print a one-line findings summary.
print_findings() {
    [ ! -f "$1" ] && return
    echo "[*] Findings: $(sarif_count "$1")"
}

# Normalize /scan/ and /tmp/ paths in SARIF to relative paths.
fix_sarif_paths() {
    [ ! -f "$1" ] && return
        jq --indent 2 '
            walk(
                if type == "string" then
                    (
                        .
                        # Remove repo scan root (/scan/) and temp directories
                        | gsub("^/scan/"; "")
                        | gsub("^/tmp/[a-z_]+[0-9]*/"; "")
                    )
                    # If the string begins with a URI scheme but NOT http/https/file,
                    # strip that leading custom scheme (e.g. "scanner-build:").
                    | (if test("^[a-zA-Z][a-zA-Z0-9+.-]*:") and (test("^(https?|file):") | not) then gsub("^[^:]+:"; "") else . end)
                    # Remove any leading file:// (if present) and trim leading slashes
                    | gsub("^file://"; "") | gsub("^/+"; "")
                else . end
            )
        ' "$1" > "${1}.tmp" && mv "${1}.tmp" "$1"
}

# Merge multiple SARIF files into one.
# Usage: merge_sarif <outfile> <part1.sarif> [part2.sarif ...]
merge_sarif() {
    local outfile="$1"; shift
    local parts=("$@")

    if [ ${#parts[@]} -eq 0 ]; then
        write_empty_sarif "${TOOL_NAME:-Scanner}" "$outfile"; return
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

# ═══════════════════════════════════════════════════════════════
#  2. PR Diff Helpers
# ═══════════════════════════════════════════════════════════════

# Get files changed in a PR matching given pathspec patterns.
# Usage: get_changed_files '*.py' 'src/**'
# Sets:  CHANGED_FILES (array)
# Returns 0 if files found, 1 otherwise.
get_changed_files() {
    CHANGED_FILES=()
    git fetch origin "${BASE_REF:-main}" --depth=1 2>/dev/null || true
    local raw
    raw=$(git diff --name-only --diff-filter=AMRC \
        "origin/${BASE_REF:-main}"...HEAD -- "$@" 2>/dev/null || true)
    [ -z "$raw" ] && return 1
    mapfile -t CHANGED_FILES <<< "$raw"
    echo "[*] Changed files (${#CHANGED_FILES[@]}):"
    printf "      %s\n" "${CHANGED_FILES[@]}"
    return 0
}

# Copy CHANGED_FILES into an isolated temp directory.
# Usage: copy_to_tmpdir "sca"
# Sets:  TMP_SCAN_DIR, SCAN_FILE_COUNT
copy_to_tmpdir() {
    TMP_SCAN_DIR="/tmp/${1:-scan}_$$"
    SCAN_FILE_COUNT=0
    mkdir -p "$TMP_SCAN_DIR"
    for f in "${CHANGED_FILES[@]}"; do
        [ ! -f "$f" ] && continue
        mkdir -p "$TMP_SCAN_DIR/$(dirname "$f")"
        cp "$f" "$TMP_SCAN_DIR/$f"
        SCAN_FILE_COUNT=$((SCAN_FILE_COUNT + 1))
    done
}

# Remove the temp directory created by copy_to_tmpdir.
cleanup_tmpdir() { [ -n "${TMP_SCAN_DIR:-}" ] && rm -rf "$TMP_SCAN_DIR"; }

# ═══════════════════════════════════════════════════════════════
#  3. Container Helpers (containers module only)
# ═══════════════════════════════════════════════════════════════

# Discover Dockerfiles based on SCAN_MODE.
# Sets: DOCKERFILES (array). Returns 0 if found, 1 if none.
discover_dockerfiles() {
    DOCKERFILES=()
    if [ "$SCAN_MODE" = "pr" ]; then
        if ! get_changed_files 'Dockerfile*' '**/Dockerfile*'; then
            return 1
        fi
        DOCKERFILES=("${CHANGED_FILES[@]}")
    else
        echo "[*] Full mode: discovering all Dockerfiles..."
        mapfile -t DOCKERFILES < <(git ls-files -- 'Dockerfile*' '**/Dockerfile*' 2>/dev/null || true)
        local clean=()
        for f in "${DOCKERFILES[@]}"; do [ -n "$f" ] && clean+=("$f"); done
        DOCKERFILES=("${clean[@]}")
        [ ${#DOCKERFILES[@]} -eq 0 ] && { echo "[*] No Dockerfiles found"; return 1; }
    fi
    echo "[*] Found ${#DOCKERFILES[@]} Dockerfile(s)"
    return 0
}

# Build a Docker image per Dockerfile and export to a self-contained tar.
# Uses `docker buildx build --output type=docker` so the tar is written
# directly during the build — this completely avoids `docker save`, which
# produces incomplete OCI tars when Docker uses the containerd image store
# (Docker 25+) and causes Trivy / Grype to fail with missing-blob errors.
#
# Falls back to docker export + rootfs extraction if buildx is unavailable.
#
# Usage: build_images "${DOCKERFILES[@]}"
# Sets:  BUILT_IMAGES (array of tar file paths or rootfs directories)
build_images() {
    BUILT_IMAGES=()
    BUILT_IMAGES_DIR="/tmp/scanner-images"
    mkdir -p "$BUILT_IMAGES_DIR"

    # Try to set up a buildx builder with docker-container driver.
    # This is required for --output type=docker,dest=<file>.
    local USE_BUILDX=false
    local BUILDER_NAME="scanner-builder"
    if command -v docker >/dev/null 2>&1 && docker buildx version >/dev/null 2>&1; then
        if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
            echo "[*] Creating buildx builder: $BUILDER_NAME"
            if docker buildx create --name "$BUILDER_NAME" --driver docker-container >/dev/null 2>&1; then
                USE_BUILDX=true
            fi
        else
            USE_BUILDX=true
        fi
    fi

    local i=0
    for df in "$@"; do
        [ ! -f "$df" ] && { echo "[!] $df not found, skipping"; continue; }
        i=$((i+1))
        local tag="scanner-build:image-${i}"
        local ctx; ctx="$(dirname "$df")"

        if $USE_BUILDX; then
            # Primary: buildx --output produces a complete Docker V2 tar
            local tarfile="${BUILT_IMAGES_DIR}/image-${i}.tar"
            echo "[*] Building $df -> $tarfile (buildx)"
            if docker buildx build --builder "$BUILDER_NAME" \
                 -f "$df" -t "$tag" \
                 --output "type=docker,dest=${tarfile}" "$ctx" 2>&1; then
                BUILT_IMAGES+=("$tarfile")
                continue
            fi
            echo "[!] Buildx export failed, falling back to docker export..."
        fi

        # Fallback: docker build + docker create + docker export -> rootfs dir.
        # docker export is NOT affected by the containerd image store bug.
        local rootfs="${BUILT_IMAGES_DIR}/rootfs-${i}"
        echo "[*] Building $df -> $rootfs (docker export)"
        if DOCKER_BUILDKIT=0 docker build -f "$df" -t "$tag" "$ctx" 2>&1; then
            local cid
            cid=$(docker create "$tag" true 2>/dev/null) || true
            if [ -n "$cid" ]; then
                mkdir -p "$rootfs"
                docker export "$cid" | tar -xf - -C "$rootfs" 2>/dev/null
                docker rm "$cid" >/dev/null 2>&1 || true
                docker rmi "$tag" >/dev/null 2>&1 || true
                BUILT_IMAGES+=("$rootfs")
            else
                echo "[!] Failed to create container from $tag"
            fi
        else
            echo "[!] Build failed for $df, skipping"
        fi
    done
    echo "[*] Built ${#BUILT_IMAGES[@]} image(s)"
}

# Remove tars/images/rootfs dirs created by build_images.
cleanup_images() {
    [ -d "${BUILT_IMAGES_DIR:-}" ] && rm -rf "$BUILT_IMAGES_DIR"
    # Remove the buildx builder container (if created)
    docker buildx rm scanner-builder >/dev/null 2>&1 || true
}

# Scan all BUILT_IMAGES using the tool-specific scan_image() function.
# Requires: scan_image <image> <outfile> to be defined by the tool script.
scan_built_images() {
    local tool_lower
    tool_lower=$(echo "${TOOL_NAME:-scanner}" | tr '[:upper:]' '[:lower:]')
    local TMP_DIR="/tmp/${tool_lower}-sarif"
    mkdir -p "$TMP_DIR"

    local j=0 PARTS=()
    for img in "${BUILT_IMAGES[@]}"; do
        j=$((j+1))
        local part="$TMP_DIR/part-${j}.sarif"
        echo "[*] Scanning $img -> $part"
        scan_image "$img" "$part"
        [ -f "$part" ] && PARTS+=("$part")
    done

    merge_sarif "$RESULTS_FILE" "${PARTS[@]}"
    print_findings "$RESULTS_FILE"
    cleanup_images
    rm -rf "$TMP_DIR"
}
