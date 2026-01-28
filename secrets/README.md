# CICD Security Scanner

GitHub Action for scanning secrets in Pull Requests using [Gitleaks](https://github.com/gitleaks/gitleaks).

## Features

✅ Scans only PR changes (diff-based)  
✅ Inline PR comments on detected secrets  
✅ SARIF format reports  
✅ Blocks merge if secrets found  
✅ Uploads artifacts for audit  

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
      - name: Scan for secrets
        uses: LauraWangQiu/cicd-security-scanner/secrets@v1
        with:
          base_ref: main
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `base_ref` | Base branch to compare against | No | `main` |

## Outputs

When secrets are detected:

- **Artifact** - `<sha>` with SARIF report
- **PR Comments** - Inline comments on affected lines
- **Workflow Failure** - Blocks the PR with error message

## Requirements

- GitHub Actions enabled
- Docker available on runner (default on `ubuntu-latest`)

## Project Structure

```
cicd-security-scanner/
└── secrets/
    ├── action.yaml              # Action definition
    ├── Dockerfile               # Scanner container (Gitleaks 8.30.0)
    ├── scripts/
    │   ├── scan.sh              # Gitleaks execution
    │   ├── check-secrets.sh     # SARIF results parser
    │   └── comment-secrets.js   # PR comment generator
    └── README.md
```

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
        uses: LauraWangQiu/cicd-security-scanner/secrets@v1
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
✅ Only reads PR diff (no personal data collected)  
✅ No data stored or transmitted externally  
✅ GDPR compliant  
✅ Open source and auditable

## Support

Issues: [GitHub Issues](https://github.com/LauraWangQiu/cicd-security-scanner/issues)  
Email: yiwang03@ucm.es | lauraonetwo443@gmail.com
