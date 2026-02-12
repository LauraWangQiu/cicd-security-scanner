# CICD Security Scanner

**Plataforma Plug-and-Play de Seguridad para Pipelines CI/CD**

> Trabajo Fin de Máster - Máster en Ciberseguridad UCM

## 📋 Descripción

Suite modular de herramientas de seguridad empaquetadas como GitHub Actions, diseñada para integrarse fácilmente en pipelines CI/CD. Cada módulo es independiente, configurable y genera reportes en formato SARIF compatible con GitHub Security.

## 🏗️ Arquitectura

```
cicd-security-scanner/
├── secrets/     # 🔐 Detección de secretos (GitLeaks, TruffleHog)
├── sca/         # 📦 Análisis de dependencias (Trivy, Grype)
├── sast/        # 🔍 Análisis estático de código (Semgrep, Bandit)
├── iac/         # 🏗️ Seguridad en IaC (Checkov, Trivy)
├── containers/  # 🐳 Escaneo de imágenes Docker (Trivy, Grype)
└── examples/    # 📝 Workflows de ejemplo
```

## 🛡️ Módulos

Cada módulo soporta múltiples herramientas intercambiables mediante el parámetro `tool`.

| Módulo | Herramientas | Default | Descripción |
|--------|-------------|---------|-------------|
| `secrets/` | [GitLeaks](https://github.com/gitleaks/gitleaks), [TruffleHog](https://github.com/trufflesecurity/trufflehog) | `gitleaks` | Detecta credenciales, API keys, tokens |
| `sca/` | [Trivy](https://github.com/aquasecurity/trivy), [Grype](https://github.com/anchore/grype) | `trivy` | Analiza vulnerabilidades en dependencias (CVEs) |
| `sast/` | [Semgrep](https://semgrep.dev/), [Bandit](https://github.com/PyCQA/bandit) | `semgrep` | Análisis estático: SQL injection, XSS, etc. |
| `iac/` | [Checkov](https://www.checkov.io/), [Trivy](https://github.com/aquasecurity/trivy) | `checkov` | Misconfigurations en Terraform, K8s, Dockerfile |
| `containers/` | [Trivy](https://github.com/aquasecurity/trivy), [Grype](https://github.com/anchore/grype) | `trivy` | Vulnerabilidades en imágenes Docker y Dockerfiles |

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
    tool: 'bandit'            # o 'semgrep' (default)
    config: 'p/security-audit'
    fail_on_findings: 'true'
```

### Selección de herramienta

Cada módulo acepta un parámetro `tool` para elegir la herramienta de escaneo:

```yaml
# Secretos con TruffleHog en vez de GitLeaks
- uses: LauraWangQiu/cicd-security-scanner/secrets@main
  with:
    tool: 'trufflehog'

# SCA con Grype en vez de Trivy
- uses: LauraWangQiu/cicd-security-scanner/sca@main
  with:
    tool: 'grype'

# IaC con Trivy en vez de Checkov
- uses: LauraWangQiu/cicd-security-scanner/iac@main
  with:
    tool: 'trivy'
```

### Opción 4: Ejecución local con Docker

```bash
# Secrets (default: gitleaks)
docker build -t scanner-secrets ./secrets
docker run --rm -v $(pwd):/scan scanner-secrets

# Secrets con TruffleHog
docker run --rm -v $(pwd):/scan -e TOOL=trufflehog scanner-secrets

# SCA (default: trivy)
docker build -t scanner-sca ./sca
docker run --rm -v $(pwd):/scan scanner-sca

# SCA con Grype
docker run --rm -v $(pwd):/scan -e TOOL=grype scanner-sca

# SAST (default: semgrep)
docker build -t scanner-sast ./sast
docker run --rm -v $(pwd):/scan scanner-sast

# SAST con Bandit
docker run --rm -v $(pwd):/scan -e TOOL=bandit scanner-sast

# IaC (default: checkov)
docker build -t scanner-iac ./iac
docker run --rm -v $(pwd):/scan scanner-iac

# IaC con Trivy
docker run --rm -v $(pwd):/scan -e TOOL=trivy scanner-iac
```

## � Añadir una nueva herramienta

La plataforma está diseñada para ser extensible. Para añadir una nueva herramienta a cualquier módulo:

1. **Crear el script de escaneo**: `scripts/scan-<nombre>.sh`
   - Debe leer las variables `SCAN_MODE`, `BASE_REF`, etc.
   - Debe generar resultados en formato **SARIF** en `/scan/results.sarif`

2. **Registrarlo en el dispatcher**: Añadir un `case` en `scripts/scan.sh`
   ```bash
   case "$TOOL" in
       nueva-herramienta)
           source "$SCRIPT_DIR/scan-nueva-herramienta.sh"
           ;;
   esac
   ```

3. **Instalar en el Dockerfile**: Añadir la instalación de la herramienta
   ```dockerfile
   RUN curl -sSfL https://... | tar -xz -C /usr/local/bin
   COPY scripts/scan-nueva-herramienta.sh /scripts/scan-nueva-herramienta.sh
   ```

4. **Actualizar el `action.yaml`**: Documentar la nueva opción en el input `tool`

> Todas las herramientas deben generar SARIF para que los comentarios en PR, subida de artefactos y security gate funcionen sin cambios.

## �📊 Salidas

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
