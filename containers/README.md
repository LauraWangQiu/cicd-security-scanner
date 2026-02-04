# Container Scanner Module

Container image vulnerability scanning using [Trivy](https://github.com/aquasecurity/trivy).

## Features

✅ Scans container images for OS and application vulnerabilities (CVEs)  
✅ Scans Dockerfiles for misconfigurations  
✅ Detects outdated base images  
✅ SARIF output for GitHub Security integration

## Usage

### Scan a specific image

```yaml
- uses: LauraWangQiu/cicd-security-scanner/containers@main
  with:
    image: 'nginx:latest'
    severity: 'HIGH,CRITICAL'
    fail_on_vulnerabilities: 'true'
```

### Scan Dockerfiles in repository

```yaml
- uses: LauraWangQiu/cicd-security-scanner/containers@main
  # No image specified = scans Dockerfiles for misconfigurations
```

### Local Docker

```bash
# Scan an image
docker build -t cicd-container-scanner .
docker run --rm \
  -v $(pwd):/scan \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e IMAGE=nginx:latest \
  cicd-container-scanner

# Scan Dockerfiles only
docker run --rm -v $(pwd):/scan cicd-container-scanner
```

## Outputs

- `results.sarif` - SARIF format for GitHub Security tab
- `results.json` - Detailed JSON with all findings

## What it detects

| Category | Examples |
|----------|----------|
| OS vulnerabilities | CVEs in Alpine, Debian, Ubuntu packages |
| Application vulnerabilities | CVEs in Python, Node.js, Java dependencies |
| Dockerfile misconfigurations | Running as root, missing HEALTHCHECK, etc. |
| Outdated base images | Using old/vulnerable base images |
