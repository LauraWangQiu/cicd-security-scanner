FROM aquasec/trivy:0.68.2

ENV GRYPE_VERSION=0.87.0

RUN apk add --no-cache bash jq sed curl docker-cli git

# Install Grype
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin v${GRYPE_VERSION}

COPY scripts/scan.sh /scan.sh
COPY scripts/scan-trivy.sh /scripts/scan-trivy.sh
COPY scripts/scan-grype.sh /scripts/scan-grype.sh
# Fix line endings (CRLF->LF) for cross-platform compatibility
RUN sed -i 's/\r$//' /scan.sh /scripts/*.sh && \
    chmod +x /scan.sh /scripts/*.sh

WORKDIR /scan

ENTRYPOINT ["/scan.sh"]
