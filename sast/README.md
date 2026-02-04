# SAST Scanner Module

Static Application Security Testing using [Semgrep](https://semgrep.dev/).

## Features

✅ Detects security vulnerabilities in source code  
✅ Supports 30+ languages (Python, JavaScript, Java, Go, etc.)  
✅ SARIF output for GitHub Security integration  
✅ Configurable rulesets

## Usage

### As GitHub Action

```yaml
- uses: LauraWangQiu/cicd-security-scanner/sast@main
  with:
    config: 'auto'  # or 'p/security-audit', 'p/ci'
    fail_on_findings: 'true'
```

### Local Docker

```bash
docker build -t cicd-sast-scanner .
docker run --rm -v $(pwd):/scan cicd-sast-scanner
```

## Outputs

- `results.sarif` - SARIF format for GitHub Security tab
- `results.json` - Detailed JSON with all findings

## Semgrep Configs

| Config | Description |
|--------|-------------|
| `auto` | Auto-detect language and apply relevant rules |
| `p/ci` | Rules optimized for CI (fewer false positives) |
| `p/security-audit` | Comprehensive security audit |
| `p/owasp-top-ten` | OWASP Top 10 vulnerabilities |
