# ──────────────────────────────────────────────────────────────
#  CICD Security Scanner — Universal Image
#
#  One Dockerfile for ALL modules. The MODULE build arg selects
#  which tools to install and which scripts to copy.
#
#  Build:
#    docker build --build-arg MODULE=secrets -t cicd-secret-scanner .
#    docker build --build-arg MODULE=sast    -t cicd-sast-scanner .
#    docker build --build-arg MODULE=sca     -t cicd-sca-scanner .
#    docker build --build-arg MODULE=iac     -t cicd-iac-scanner .
#    docker build --build-arg MODULE=containers -t cicd-container-scanner .
# ──────────────────────────────────────────────────────────────
FROM python:3.11-slim

ARG MODULE

# Common system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git jq bash curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Tool installer (central registry)
COPY shared/install-tool.sh /scripts/install-tool.sh
RUN sed -i 's/\r$//' /scripts/install-tool.sh && chmod +x /scripts/install-tool.sh

# Install module-specific tools listed in tools.txt
COPY ${MODULE}/tools.txt /tmp/tools.txt
RUN /scripts/install-tool.sh /tmp/tools.txt && rm -f /tmp/tools.txt

# Shared helpers + module scripts
COPY shared/helpers.sh /scripts/helpers.sh
COPY ${MODULE}/scripts/scan.sh /scan.sh
COPY ${MODULE}/scripts/scan-*.sh /scripts/

# Fix line endings (CRLF -> LF) for cross-platform compatibility
RUN sed -i 's/\r$//' /scan.sh /scripts/*.sh && \
    chmod +x /scan.sh /scripts/*.sh

WORKDIR /scan
ENTRYPOINT ["/scan.sh"]
