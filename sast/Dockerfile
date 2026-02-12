FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    git jq bash ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install SAST tools: Semgrep + Bandit
RUN pip install --no-cache-dir semgrep bandit[sarif]

COPY scripts/scan.sh /scan.sh
COPY scripts/scan-semgrep.sh /scripts/scan-semgrep.sh
COPY scripts/scan-bandit.sh /scripts/scan-bandit.sh
# Fix line endings (CRLF->LF) for cross-platform compatibility
RUN sed -i 's/\r$//' /scan.sh /scripts/*.sh && \
    chmod +x /scan.sh /scripts/*.sh

WORKDIR /scan

ENTRYPOINT ["/scan.sh"]
