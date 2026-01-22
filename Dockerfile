FROM debian:12-slim

ENV GITLEAKS_VERSION=8.30.0

RUN apt-get update && apt-get install -y \
    curl git jq bash ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz \
    | tar -xz -C /usr/local/bin gitleaks

COPY scan.sh /scan.sh
RUN chmod +x /scan.sh

ENTRYPOINT ["/scan.sh"]
