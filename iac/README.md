# IaC Scanner Module

Escaneo de seguridad en Infrastructure as Code usando [Checkov](https://www.checkov.io/) y [Trivy](https://github.com/aquasecurity/trivy).

## Características

✅ **Dos herramientas** intercambiables: Checkov (default), Trivy  
✅ Detecta misconfiguraciones en Terraform, Kubernetes, Dockerfile, CloudFormation...  
✅ 1000+ políticas de seguridad integradas (Checkov)  
✅ Modo PR: escanea solo ficheros IaC cambiados  
✅ Reportes SARIF compatibles con GitHub Security  
✅ Frameworks de compliance (CIS, SOC2, HIPAA, etc.)

## Herramientas

| Herramienta | Descripción |
|-------------|-------------|
| [Checkov](https://www.checkov.io/) | Motor de políticas con 1000+ reglas integradas |
| [Trivy](https://github.com/aquasecurity/trivy) | Scanner multi-propósito (modo `config`) |

Las versiones se definen en `tools.txt` y se instalan automáticamente.

## Frameworks soportados

| Framework | Tipos de fichero |
|-----------|-----------------|
| Terraform | `.tf`, `.tf.json` |
| Kubernetes | `.yaml`, `.yml` (manifiestos K8s) |
| Dockerfile | `Dockerfile*` |
| CloudFormation | `.yaml`, `.json` (templates CFN) |
| Helm | Charts de Helm |
| ARM | Azure Resource Manager templates |

## Uso

### Como GitHub Action

```yaml
- uses: LauraWangQiu/cicd-security-scanner/iac@main
  with:
    tool: 'checkov'             # o 'trivy'
    framework: 'all'            # o 'terraform', 'kubernetes', 'dockerfile'
    scan_mode: 'full'           # o 'pr'
    fail_on_findings: 'true'
```

### Inputs

| Input | Descripción | Requerido | Default |
|-------|-------------|-----------|---------|
| `tool` | Herramienta: `checkov`, `trivy` | No | `checkov` |
| `framework` | Frameworks a escanear: `all`, `terraform`, `kubernetes`, `dockerfile` | No | `all` |
| `scan_mode` | Modo: `full` (repo entero) o `pr` (solo ficheros IaC cambiados) | No | `full` |
| `base_ref` | Rama base para comparación PR diff | No | `main` |
| `fail_on_findings` | Fallar el workflow si hay misconfiguraciones | No | `true` |

### Ejecución local con Docker

```bash
# Desde la raíz del repositorio cicd-security-scanner/
docker build --build-arg MODULE=iac -t cicd-iac-scanner .

# Escanear con Checkov (default)
docker run --rm -v /path/to/repo:/scan cicd-iac-scanner

# Escanear con Trivy
docker run --rm -v /path/to/repo:/scan -e TOOL=trivy cicd-iac-scanner

# Solo terraform
docker run --rm -v /path/to/repo:/scan -e FRAMEWORK=terraform cicd-iac-scanner
```

## Salidas

- `results.sarif` — Formato SARIF para GitHub Security tab
- Artefacto `iac-results-<sha>.sarif`
- Comentarios inline en PR

## ➕ Añadir otra herramienta IaC

1. Registrar la instalación en `shared/install-tool.sh`
2. Añadir la herramienta a `iac/tools.txt`
3. Crear `iac/scripts/scan-<tool>.sh` que genere SARIF en `$RESULTS_FILE`

## Estructura del módulo

```
iac/
├── action.yaml
├── tools.txt                 # checkov, trivy
├── scripts/
│   ├── scan.sh               # Dispatcher
│   ├── scan-checkov.sh        # Lógica Checkov
│   ├── scan-trivy.sh         # Lógica Trivy (modo config)
│   └── comment-findings.js   # Comentarios PR
└── README.md
```

## Licencia

MIT
