FROM aquasec/trivy:0.68.2

RUN apk add --no-cache bash jq sed

COPY scripts/scan.sh /scan.sh
# Fix line endings (CRLF->LF) for cross-platform compatibility
RUN sed -i 's/\r$//' /scan.sh && chmod +x /scan.sh

WORKDIR /scan

ENTRYPOINT ["/scan.sh"]
