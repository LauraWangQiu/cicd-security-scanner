FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    git jq bash ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Install IaC tools: Checkov + Trivy
RUN pip install --no-cache-dir checkov

ENV TRIVY_VERSION=0.68.2
RUN curl -sSfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v${TRIVY_VERSION}

COPY scripts/scan.sh /scan.sh
COPY scripts/scan-checkov.sh /scripts/scan-checkov.sh
COPY scripts/scan-trivy.sh /scripts/scan-trivy.sh
# Fix line endings (CRLF->LF) for cross-platform compatibility
RUN sed -i 's/\r$//' /scan.sh /scripts/*.sh && \
    chmod +x /scan.sh /scripts/*.sh

WORKDIR /scan

ENTRYPOINT ["/scan.sh"]
