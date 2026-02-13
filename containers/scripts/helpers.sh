#!/bin/bash
# ──────────────────────────────────────────────────────────────
#  Shared helpers for container scanners (Trivy, Grype, …)
#  Sourced by scan-<tool>.sh — do not run directly
# ──────────────────────────────────────────────────────────────

# ── empty_sarif <tool_name> ──────────────────────────────────
#  Prints a minimal valid SARIF envelope for the given tool.
empty_sarif() {
    local tool_name="${1:-Scanner}"
    cat <<EOF
{"version":"2.1.0","\$schema":"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"${tool_name}","rules":[]}},"results":[]}]}
EOF
}

# ── write_empty_sarif <tool_name> <outfile> ──────────────────
write_empty_sarif() {
    empty_sarif "$1" > "$2"
}

# ── discover_dockerfiles ─────────────────────────────────────
#  Populates the global array DOCKERFILES with paths depending
#  on SCAN_MODE (full | pr).
#  Returns 0 if files found, 1 if none.
discover_dockerfiles() {
    DOCKERFILES=()

    if [ "$SCAN_MODE" = "pr" ]; then
        echo "[*] PR mode: detecting changed Dockerfiles..."
        git fetch origin "$BASE_REF" --depth=1 2>/dev/null || true
        local changed
        changed=$(git diff --name-only --diff-filter=AMRC \
            "origin/$BASE_REF"...HEAD -- 'Dockerfile*' '**/Dockerfile*' 2>/dev/null || true)

        if [ -z "$changed" ]; then
            echo "[*] No Dockerfiles changed in this PR"
            return 1
        fi
        echo "[*] Changed Dockerfiles:"
        echo "$changed"
        mapfile -t DOCKERFILES <<< "$changed"
    else
        echo "[*] Full mode: discovering all Dockerfiles..."
        mapfile -t DOCKERFILES < <(git ls-files -- 'Dockerfile*' '**/Dockerfile*' 2>/dev/null || true)
        # Filter empty entries
        local clean=()
        for f in "${DOCKERFILES[@]}"; do
            [ -n "$f" ] && clean+=("$f")
        done
        DOCKERFILES=("${clean[@]}")

        if [ ${#DOCKERFILES[@]} -eq 0 ]; then
            echo "[*] No Dockerfiles found in repository"
            return 1
        fi
    fi

    echo "[*] Found ${#DOCKERFILES[@]} Dockerfile(s)"
    return 0
}

# ── build_images <dockerfile…> ───────────────────────────────
#  Builds a Docker image for each Dockerfile.
#  Populates the global array BUILT_IMAGES with the resulting tags.
build_images() {
    BUILT_IMAGES=()
    local i=0

    for df in "$@"; do
        [ ! -f "$df" ] && { echo "[!] $df not found, skipping"; continue; }
        i=$((i+1))
        local tag="scanner-build:image-${i}"
        local context
        context="$(dirname "$df")"

        echo "[*] Building $df (context: $context) -> $tag"
        if docker build -f "$df" -t "$tag" "$context" 2>&1; then
            BUILT_IMAGES+=("$tag")
        else
            echo "[!] Failed to build $df, skipping"
        fi
    done

    echo "[*] Successfully built ${#BUILT_IMAGES[@]} image(s)"
    return 0
}

# ── cleanup_images ───────────────────────────────────────────
#  Removes all images listed in BUILT_IMAGES.
cleanup_images() {
    for img in "${BUILT_IMAGES[@]}"; do
        docker rmi "$img" 2>/dev/null || true
    done
}

# ── merge_sarif <outfile> <part1> [part2 …] ──────────────────
#  Merges one or more SARIF files into a single output.
#  If no parts, writes an empty SARIF for the given TOOL_NAME.
merge_sarif() {
    local outfile="$1"; shift
    local parts=("$@")

    if [ ${#parts[@]} -eq 0 ]; then
        write_empty_sarif "${TOOL_NAME:-Scanner}" "$outfile"
        return
    fi

    if [ ${#parts[@]} -eq 1 ]; then
        cp "${parts[0]}" "$outfile"
        return
    fi

    jq -s '{
        "version": "2.1.0",
        "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json",
        "runs": [.[].runs[]]
    }' "${parts[@]}" > "$outfile"
}

# ── print_summary <sarif_file> ───────────────────────────────
print_summary() {
    local sarif="$1"
    if [ -f "$sarif" ]; then
        local count
        count=$(jq '[.runs[].results[]] | length' "$sarif" 2>/dev/null || echo "0")
        echo "[*] Total findings across all images: $count"
    fi
}
