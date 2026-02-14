# CICD Security Scanner

**Plataforma Plug-and-Play de Seguridad para Pipelines CI/CD**

> Trabajo Fin de Máster - Máster en Ciberseguridad UCM

## 📋 Descripción

Suite modular de herramientas de seguridad empaquetadas como GitHub Actions, diseñada para integrarse fácilmente en pipelines CI/CD. Cada módulo es independiente, configurable y genera reportes en formato SARIF compatible con GitHub Security.

## 🏗️ Arquitectura

```
cicd-security-scanner/
├── Dockerfile              # 🐳 Imagen universal (una sola para todos los módulos)
├── Makefile                # 🔧 Build de las imágenes de cada módulo
├── shared/                 # 📦 Código compartido
│   ├── helpers.sh          #   Funciones comunes (SARIF, PR diff, merge, containers...)
│   ├── check-results.sh    #   Verificador de resultados para action.yaml
│   └── install-tool.sh     #   Instalador central de herramientas
├── secrets/                # 🔐 Detección de secretos
│   ├── action.yaml
│   ├── tools.txt           #   gitleaks, trufflehog
│   └── scripts/
├── sast/                   # 🔍 Análisis estático de código
│   ├── action.yaml
│   ├── tools.txt           #   semgrep, bandit
│   └── scripts/
├── sca/                    # 📦 Análisis de dependencias
│   ├── action.yaml
│   ├── tools.txt           #   trivy, grype
│   └── scripts/
├── iac/                    # 🏗️ Seguridad en IaC
│   ├── action.yaml
│   ├── tools.txt           #   checkov, trivy
│   └── scripts/
├── containers/             # 🐳 Escaneo de imágenes Docker
│   ├── action.yaml
│   ├── tools.txt           #   trivy, grype, docker-cli
│   └── scripts/
└── examples/               # 📝 Workflows de ejemplo
```

### Imagen universal

Un único `Dockerfile` en la raíz sirve para todos los módulos. El argumento `MODULE` selecciona qué herramientas instalar y qué scripts copiar:

```bash
docker build --build-arg MODULE=secrets -t cicd-secret-scanner .
```

Las herramientas de cada módulo se definen en su `tools.txt` y se instalan automáticamente mediante `shared/install-tool.sh`.

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
# Desde la raíz del repositorio cicd-security-scanner/

# Secrets (default: gitleaks)
docker build --build-arg MODULE=secrets -t cicd-secret-scanner .
docker run --rm -v $(pwd):/scan cicd-secret-scanner

# Secrets con TruffleHog
docker run --rm -v $(pwd):/scan -e TOOL=trufflehog cicd-secret-scanner

# SCA (default: trivy)
docker build --build-arg MODULE=sca -t cicd-sca-scanner .
docker run --rm -v $(pwd):/scan cicd-sca-scanner

# SAST (default: semgrep)
docker build --build-arg MODULE=sast -t cicd-sast-scanner .
docker run --rm -v $(pwd):/scan cicd-sast-scanner

# IaC (default: checkov)
docker build --build-arg MODULE=iac -t cicd-iac-scanner .
docker run --rm -v $(pwd):/scan cicd-iac-scanner

# Containers (default: trivy)
docker build --build-arg MODULE=containers -t cicd-container-scanner .
docker run --rm -v $(pwd):/scan -v /var/run/docker.sock:/var/run/docker.sock cicd-container-scanner
```

O usando el Makefile:

```bash
make secrets    # build secrets scanner
make sast       # build sast scanner
make all        # build all scanners
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

Todos los módulos generan un `results.sarif` en formato SARIF 2.1.0:

- **GitHub Security tab**: subida automática via `codeql-action/upload-sarif`
- **Artefactos**: `<módulo>-results-<sha>.sarif`
- **Comentarios PR**: resumen de hallazgos inline
- **Security gate**: falla el workflow si se encuentran hallazgos (configurable)

## ⚙️ Configuración

Ver README de cada módulo para opciones específicas:
- [secrets/README.md](secrets/README.md)
- [sast/README.md](sast/README.md)
- [sca/README.md](sca/README.md)
- [iac/README.md](iac/README.md)
- [containers/README.md](containers/README.md)

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

- Imagen Docker universal mínima (`python:3.11-slim`)
- Sin credenciales embebidas
- Principio de mínimo privilegio
- Escaneo de las propias imágenes con Trivy

## 📄 Licencia

MIT License - Ver [LICENSE](LICENSE)

## 👩‍💻 Autor

Laura Wang Qiu - Máster en Ciberseguridad UCM 2024-2025
