# CICD SCA Scanner

GitHub Action for scanning dependency vulnerabilities in Pull Requests using [Trivy](https://github.com/aquasecurity/trivy).

## Features

✅ Multi-language support (Node, Python, Java, Go, Ruby, .NET, Rust, PHP)  
✅ Automatic lockfile detection  
✅ Configurable severity threshold  
✅ PR comments with vulnerability summary  
✅ SARIF format reports  
✅ Blocks merge if vulnerabilities found  

## Supported Files

| Language | Files |
|----------|-------|
| Node.js | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` |
| Python | `requirements.txt`, `Pipfile.lock`, `poetry.lock` |
| Java | `pom.xml`, `build.gradle`, `build.gradle.kts` |
| Go | `go.sum` |
| Ruby | `Gemfile.lock` |
| .NET | `packages.lock.json`, `*.csproj` |
| Rust | `Cargo.lock` |
| PHP | `composer.lock` |

## Usage

```yaml
name: Dependency Scanning

on:
  pull_request:
    branches: [ "main" ]

jobs:
  sca:
    runs-on: ubuntu-latest
    steps:
      - name: Scan dependencies
        uses: LauraWangQiu/cicd-security-scanner/sca@v1
        with:
          severity: HIGH,CRITICAL
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `severity` | Minimum severity to report (CRITICAL, HIGH, MEDIUM, LOW) | No | `HIGH,CRITICAL` |
| `fail_on_vulnerabilities` | Fail workflow if vulnerabilities found | No | `true` |

## Outputs

When vulnerabilities are detected:

- **Artifact** - `sca-results-<sha>` with SARIF report
- **PR Comment** - Summary table with affected packages
- **Workflow Failure** - Blocks the PR (configurable)

## Example Output

The action posts a comment like:

> ## 🔓 Dependency Vulnerabilities Found
> 
> **Total:** 3 vulnerability(ies)
> 
> | Package | Vulnerabilities | Severity |
> |---------|-----------------|----------|
> | `lodash` | 2 | HIGH |
> | `axios` | 1 | CRITICAL |

## Project Structure

```
sca/
├── action.yaml              # Action definition
├── Dockerfile               # Trivy container
├── scripts/
│   ├── scan.sh              # Trivy execution
│   ├── check-results.sh     # SARIF results parser
│   └── comment-vulnerabilities.js  # PR comment generator
└── README.md
```

## License

MIT
