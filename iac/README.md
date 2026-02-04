# IaC Scanner Module

Infrastructure as Code security scanning using [Checkov](https://www.checkov.io/).

## Features

✅ Detects misconfigurations in Terraform, Kubernetes, Dockerfile, CloudFormation, etc.  
✅ 1000+ built-in policies  
✅ SARIF output for GitHub Security integration  
✅ Compliance frameworks (CIS, SOC2, HIPAA, etc.)

## Usage

### As GitHub Action

```yaml
- uses: LauraWangQiu/cicd-security-scanner/iac@main
  with:
    framework: 'all'  # or 'terraform', 'kubernetes', 'dockerfile'
    fail_on_findings: 'true'
```

### Local Docker

```bash
docker build -t cicd-iac-scanner .
docker run --rm -v $(pwd):/scan cicd-iac-scanner
```

## Outputs

- `results.sarif` - SARIF format for GitHub Security tab
- `results.json` - Detailed JSON with all findings

## Supported Frameworks

| Framework | File Types |
|-----------|------------|
| Terraform | `.tf`, `.tf.json` |
| Kubernetes | `.yaml`, `.yml` (K8s manifests) |
| Dockerfile | `Dockerfile*` |
| CloudFormation | `.yaml`, `.json` (CFN templates) |
| Helm | Helm charts |
| ARM | Azure Resource Manager templates |
