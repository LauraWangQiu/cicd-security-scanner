#!/bin/bash
# ──────────────────────────────────────────────────────────────
#  Tool Installer — Central registry for ALL scanner tools
#
#  Usage:  install-tool.sh <tools.txt>
#  Format: <tool-name> [version]   (one per line, # = comments)
#
#  ┌─────────────────────────────────────────────────────────┐
#  │  TO ADD A NEW TOOL (e.g. Snyk):                        │
#  │    1. Add a case block to this script                  │
#  │    2. Add "snyk <version>" to the module's tools.txt   │
#  │    3. Create scan-snyk.sh in the module's scripts/     │
#  │    That's it — no Dockerfile changes needed.           │
#  └─────────────────────────────────────────────────────────┘
# ──────────────────────────────────────────────────────────────
set -e

TOOLS_FILE="${1:?Usage: install-tool.sh <tools.txt>}"

install_one() {
    local tool="$1" version="$2"

    # Sanitize inputs (strip CR/LF and surrounding whitespace)
    tool="$(printf '%s' "$tool" | tr -d '\r' )"
    version="$(printf '%s' "$version" | tr -d '\r' )"
    tool="${tool#${tool%%[![:space:]]*}}"
    tool="${tool%${tool##*[![:space:]]}}"
    version="${version#${version%%[![:space:]]*}}"
    version="${version%${version##*[![:space:]]}}"

    # Require explicit versions for tarball-based installers to avoid malformed URLs
    case "$tool" in
        gitleaks|trufflehog|trivy|grype)
            if [ -z "$version" ]; then
                echo "[!] $tool requires a version in tools.txt (e.g. '$tool 8.30.0')"
                exit 1
            fi
            ;;
    esac

    case "$tool" in
        # ── Secret scanners ──────────────────────────────────
        gitleaks)
            curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_linux_x64.tar.gz" \
                | tar -xz -C /usr/local/bin gitleaks
            ;;
        trufflehog)
            curl -sSfL "https://github.com/trufflesecurity/trufflehog/releases/download/v${version}/trufflehog_${version}_linux_amd64.tar.gz" \
                | tar -xz -C /usr/local/bin trufflehog
            ;;

        # ── SAST scanners ────────────────────────────────────
        semgrep)
            pip install --no-cache-dir "semgrep${version:+==$version}"
            ;;
        bandit)
            pip install --no-cache-dir "bandit[sarif]${version:+==$version}"
            ;;

        # ── SCA / Container scanners ─────────────────────────
        trivy)
            curl -sSfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
                | sh -s -- -b /usr/local/bin "v${version}"
            ;;
        grype)
            curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \
                | sh -s -- -b /usr/local/bin "v${version}"
            ;;

        # ── IaC scanners ─────────────────────────────────────
        checkov)
            pip install --no-cache-dir "checkov${version:+==$version}"
            ;;

        # ── System packages ──────────────────────────────────
        docker-cli)
            local docker_ver="${version:-27.5.1}"
            curl -sSfL "https://download.docker.com/linux/static/stable/x86_64/docker-${docker_ver}.tgz" \
                | tar -xz --strip-components=1 -C /usr/local/bin docker/docker
            chmod +x /usr/local/bin/docker
            ;;
        docker-buildx)
            local bx_ver="${version:-0.19.3}"
            mkdir -p /usr/lib/docker/cli-plugins
            curl -sSfL "https://github.com/docker/buildx/releases/download/v${bx_ver}/buildx-v${bx_ver}.linux-amd64" \
                -o /usr/lib/docker/cli-plugins/docker-buildx
            chmod +x /usr/lib/docker/cli-plugins/docker-buildx
            ;;
        *)
            echo "[!] Unknown tool: $tool"
            exit 1
            ;;
    esac

    echo "[+] Installed $tool ${version:-latest}"
}

# ── Parse tools.txt and install each entry (robust parsing)
echo "=== Installing tools ==="
while IFS= read -r line || [ -n "$line" ]; do
    # Remove CR, strip comments and trim whitespace
    line="$(printf '%s' "$line" | tr -d '\r')"
    line="${line%%#*}"
    line="${line#${line%%[![:space:]]*}}"
    line="${line%${line##*[![:space:]]}}"
    [ -z "$line" ] && continue

    # Split into tool and optional version
    set -- $line
    tool="$1"
    version="$2"
    install_one "$tool" "$version"
done < "$TOOLS_FILE"
echo "=== All tools installed ==="
