# CICD Security Scanner

GitHub Action for scanning secrets in PRs using Gitleaks.

## Features

✅ Scans only PR changes (diff)  
✅ Redacts secrets in reports  
✅ Creates automatic PR comments  
✅ Blocks merge if secrets found  
✅ Generates JSON reports for audit  

## Usage

Create `.github/workflows/secrets.yaml`:

```yaml
name: Secret Scanning

on:
  pull_request:
    branches: [ "main" ]

jobs:
  secrets:
    runs-on: ubuntu-latest
    steps:
      - name: Run scanner
        uses: LauraWangQiu/cicd-security-scanner@v0
        with:
          base_ref: main
```

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `base_ref` | Base branch to compare against | `main` |

## Outputs

Generates an artifact with:

- `gitleaks.json` - Detailed scan report
- `pr.diff` - Scanned diff
- `metadata.txt` - Commit metadata

## Requirements

- GitHub Actions enabled
- Docker available on runner

## Real Example

```yaml
name: PR Security Check

on:
  pull_request:
    branches: [ main, develop ]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - name: Scan for secrets
        uses: LauraWangQiu/cicd-security-scanner@v1
        with:
          base_ref: ${{ github.base_ref }}
```

## Troubleshooting

**Error: "docker build not found"**

- Use `ubuntu-latest` as the runner

**Secrets that should be detected aren't being found**

- Check `.gitleaks.toml` in your repository
- Ensure patterns are enabled

## License

MIT

## Privacy & Security

This Action:
✅ Only reads PR diff (no Personal Data collected)
✅ No data stored or transmitted externally
✅ GDPR compliant
✅ Open source and auditable

## Support

Issues: GitHub Issues  
Email: yiwang03@ucm.es
