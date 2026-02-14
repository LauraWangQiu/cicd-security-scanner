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
            apt-get update -qq \
                && apt-get install -y -qq --no-install-recommends docker.io \
                && rm -rf /var/lib/apt/lists/*
            ;;

        *)
            echo "[!] Unknown tool: $tool"
            exit 1
            ;;
    esac

    echo "[+] Installed $tool ${version:-latest}"
}

# ── Parse tools.txt and install each entry ────────────────────
echo "=== Installing tools ==="
while IFS=' ' read -r tool version || [ -n "$tool" ]; do
    # Skip comments and empty lines
    [[ -z "$tool" || "$tool" == \#* ]] && continue
    install_one "$tool" "$version"
done < "$TOOLS_FILE"
echo "=== All tools installed ==="
