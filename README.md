# CICD Security Scanner

**Plataforma Plug-and-Play de Seguridad para Pipelines CI/CD**

> Trabajo Fin de Máster - Máster en Ciberseguridad UCM

## 📋 Descripción

Suite modular de herramientas de seguridad empaquetadas como GitHub Actions, diseñada para integrarse fácilmente en pipelines CI/CD. Cada módulo es independiente, configurable y genera reportes en formato SARIF compatible con GitHub Security.

## 🏗️ Arquitectura

```
cicd-security-scanner/
├── secrets/     # 🔐 Detección de secretos (GitLeaks)
├── sca/         # 📦 Análisis de dependencias (Trivy)
├── sast/        # 🔍 Análisis estático de código (Semgrep)
├── iac/         # 🏗️ Seguridad en IaC (Checkov)
├── containers/  # 🐳 Escaneo de imágenes Docker (Trivy)
└── examples/    # 📝 Workflows de ejemplo
```

## 🛡️ Módulos

| Módulo | Herramienta | Descripción |
|--------|-------------|-------------|
| `secrets/` | [GitLeaks](https://github.com/gitleaks/gitleaks) | Detecta credenciales, API keys, tokens en código y commits |
| `sca/` | [Trivy](https://github.com/aquasecurity/trivy) | Analiza vulnerabilidades en dependencias (CVEs) |
| `sast/` | [Semgrep](https://semgrep.dev/) | Análisis estático: SQL injection, XSS, etc. |
| `iac/` | [Checkov](https://www.checkov.io/) | Misconfigurations en Terraform, K8s, Dockerfile |
| `containers/` | [Trivy](https://github.com/aquasecurity/trivy) | Vulnerabilidades en imágenes Docker y Dockerfiles |

## 🚀 Uso Rápido

### Opción 1: Workflow completo (manual)

```yaml
# .github/workflows/security.yaml
name: Security Pipeline

on:
  workflow_dispatch:
    inputs:
      scan_secrets:
        description: 'Run Secrets scan'
        required: false
        default: true
        type: boolean
      secrets_mode:
        description: 'Secret scan mode (only if scan_secrets is true)'
        required: false
        default: 'all'
        type: choice
        options:
          - all
          - files
          - history
      scan_sast:
        description: 'Run SAST scan'
        required: false
        default: true
        type: boolean
      scan_sca:
        description: 'Run SCA scan'
        required: false
        default: true
        type: boolean
      scan_iac:
        description: 'Run IaC scan'
        required: false
        default: true
        type: boolean
      scan_containers:
        description: 'Run Container scan'
        required: false
        default: true
        type: boolean

jobs:
  secrets:
    uses: LauraWangQiu/cicd-security-scanner/secrets@main
    with:
      scan_mode: ${{ inputs.secrets_mode }}
  sca:
    uses: LauraWangQiu/cicd-security-scanner/sca@main
  sast:
    uses: LauraWangQiu/cicd-security-scanner/sast@main
  iac:
    uses: LauraWangQiu/cicd-security-scanner/iac@main
  containers:
    uses: LauraWangQiu/cicd-security-scanner/containers@main
```

### Opción 2: Ejemplo para PRs (escaneo en pull_request con `scan_mode`)

```yaml
# .github/workflows/security-pr.yaml
name: Security Pipeline (PR)

on: [pull_request]

jobs:
  secrets:
    uses: LauraWangQiu/cicd-security-scanner/secrets@main
    with:
      scan_mode: 'pr'
      base_ref: ${{ github.base_ref }}

  sca:
    uses: LauraWangQiu/cicd-security-scanner/sca@main

  sast:
    uses: LauraWangQiu/cicd-security-scanner/sast@main

  iac:
    uses: LauraWangQiu/cicd-security-scanner/iac@main

  containers:
    uses: LauraWangQiu/cicd-security-scanner/containers@main
```

### Opción 3: Módulos individuales

```yaml
- uses: LauraWangQiu/cicd-security-scanner/sast@main
  with:
    config: 'p/security-audit'
    fail_on_findings: 'true'
```

### Opción 3: Ejecución local con Docker

```bash
# Secrets
docker build -t scanner-secrets ./secrets
docker run --rm -v $(pwd):/scan scanner-secrets

# SCA
docker build -t scanner-sca ./sca
docker run --rm -v $(pwd):/scan scanner-sca

# SAST
docker build -t scanner-sast ./sast
docker run --rm -v $(pwd):/scan scanner-sast

# IaC
docker build -t scanner-iac ./iac
docker run --rm -v $(pwd):/scan scanner-iac
```

## 📊 Salidas

Todos los módulos generan un `results.sarif`

## ⚙️ Configuración

Ver README de cada módulo para opciones específicas:
- [secrets/README.md](secrets/README.md)
- [sca/README.md](sca/README.md)
- [sast/README.md](sast/README.md)
- [iac/README.md](iac/README.md)

## 🧪 Validación

Probado contra repositorios vulnerables:
- [OWASP Juice Shop](https://github.com/juice-shop/juice-shop)
- [CICD-Goat](https://github.com/cider-security-research/cicd-goat)
- [Damn Vulnerable Web Application](https://github.com/digininja/DVWA)

## 📈 Métricas de Evaluación

| Métrica | Descripción |
|---------|-------------|
| Detección (Recall) | % de vulnerabilidades conocidas detectadas |
| Precisión | % de hallazgos que son verdaderos positivos |
| Tiempo de ejecución | Segundos por análisis |
| Tasa de FP | Falsos positivos por 1000 líneas de código |

## 🔒 Seguridad de la Plataforma

- Imágenes Docker mínimas (slim/alpine)
- Sin credenciales embebidas
- Principio de mínimo privilegio
- Escaneo de las propias imágenes con Trivy

## 📄 Licencia

MIT License - Ver [LICENSE](LICENSE)

## 👩‍💻 Autor

Laura Wang Qiu - Máster en Ciberseguridad UCM 2024-2025
