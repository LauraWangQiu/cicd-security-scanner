# Release Notes

## v1 - Initial Release

🎉 **First stable release of CICD Security Scanner**

A GitHub Action for automated secret detection in Pull Requests using [Gitleaks](https://github.com/gitleaks/gitleaks).

### ✨ Features

- **PR Diff Scanning** - Only scans changes introduced in the Pull Request, not the entire codebase
- **Inline PR Comments** - Automatically comments on the exact lines where secrets are detected
- **SARIF Reports** - Generates standardized SARIF format reports for security tooling integration
- **Artifact Upload** - Uploads scan results as workflow artifacts for audit and review
- **Merge Blocking** - Fails the workflow if secrets are found, preventing accidental exposure
- **Secret Redaction** - Protects sensitive data in reports and logs

### 📦 Components

- **Gitleaks v8.30.0** - Industry-standard secret detection engine
- **Docker-based** - Consistent execution environment across all runners
- **Minimal footprint** - Based on Debian 12 slim image

### 🚀 Quick Start

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
        uses: LauraWangQiu/cicd-security-scanner@v1
        with:
          base_ref: main
```

### ⚙️ Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `base_ref` | Base branch to compare against | No | `main` |

### 📤 Outputs

When secrets are detected:
- **Workflow artifact** - `<sha>` containing SARIF report
- **PR comments** - Inline comments on affected lines
- **Workflow failure** - Exit code 1 with error message

### 🔧 Requirements

- GitHub Actions enabled on repository
- `pull_request` event trigger
- Docker available on runner (default on `ubuntu-latest`)

### 📁 Files

```
cicd-security-scanner/
├── action.yaml              # Action definition
├── Dockerfile               # Scanner container
├── scripts/
│   ├── scan.sh              # Gitleaks execution script
│   ├── check-secrets.sh     # SARIF results parser
│   └── comment-secrets.js   # PR comment generator
└── README.md
```

---

**Full Changelog**: https://github.com/LauraWangQiu/cicd-security-scanner/commits/v1
