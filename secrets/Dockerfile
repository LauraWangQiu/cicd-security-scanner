FROM debian:12-slim

ENV GITLEAKS_VERSION=8.30.0
ENV TRUFFLEHOG_VERSION=3.93.3

RUN apt-get update && apt-get install -y \
    curl git jq bash ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Gitleaks
RUN curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz \
    | tar -xz -C /usr/local/bin gitleaks

# Install TruffleHog
RUN curl -sSfL https://github.com/trufflesecurity/trufflehog/releases/download/v${TRUFFLEHOG_VERSION}/trufflehog_${TRUFFLEHOG_VERSION}_linux_amd64.tar.gz \
    | tar -xz -C /usr/local/bin trufflehog

COPY scripts/scan.sh /scan.sh
COPY scripts/scan-gitleaks.sh /scripts/scan-gitleaks.sh
COPY scripts/scan-trufflehog.sh /scripts/scan-trufflehog.sh
# Fix line endings (CRLF->LF) for cross-platform compatibility
RUN sed -i 's/\r$//' /scan.sh /scripts/*.sh && \
    chmod +x /scan.sh /scripts/*.sh

ENTRYPOINT ["/scan.sh"]
