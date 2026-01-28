FROM aquasec/trivy:0.68.2

# Install jq for JSON processing
RUN apk add --no-cache bash jq

COPY scripts/scan.sh /scan.sh
RUN chmod +x /scan.sh

WORKDIR /scan

ENTRYPOINT ["/scan.sh"]
