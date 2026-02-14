# SAST Scanner Module

Análisis estático de seguridad de código fuente usando [Semgrep](https://semgrep.dev/) y [Bandit](https://github.com/PyCQA/bandit).

## Características

✅ **Dos herramientas** intercambiables: Semgrep (default), Bandit  
✅ Detecta vulnerabilidades en código fuente (SQL injection, XSS, etc.)  
✅ Soporte para 30+ lenguajes (Python, JavaScript, Java, Go, etc.)  
✅ Modo PR: escanea solo ficheros cambiados  
✅ Reportes SARIF compatibles con GitHub Security  

## Herramientas

| Herramienta | Descripción | Lenguajes |
|-------------|-------------|-----------|
| [Semgrep](https://semgrep.dev/) | Motor de reglas multi-lenguaje, configurable | 30+ lenguajes |
| [Bandit](https://github.com/PyCQA/bandit) | Especializado en seguridad Python | Python |

Las versiones se definen en `tools.txt` y se instalan automáticamente.

## Uso

### Como GitHub Action

```yaml
- uses: LauraWangQiu/cicd-security-scanner/sast@main
  with:
    tool: 'semgrep'             # o 'bandit'
    config: 'auto'              # config de Semgrep
    severity: 'MEDIUM'
    scan_mode: 'full'           # o 'pr'
    fail_on_findings: 'true'
```

### Inputs

| Input | Descripción | Requerido | Default |
|-------|-------------|-----------|---------|
| `tool` | Herramienta: `semgrep`, `bandit` | No | `semgrep` |
| `config` | Config de Semgrep: `auto`, `p/ci`, `p/security-audit`, etc. | No | `auto` |
| `severity` | Severidad mínima. Semgrep: `ERROR`,`WARNING`. Bandit: `LOW`,`MEDIUM`,`HIGH` | No | `MEDIUM` |
| `scan_mode` | Modo: `full` (repo entero) o `pr` (solo ficheros cambiados) | No | `full` |
| `base_ref` | Rama base para comparación PR diff | No | `main` |
| `fail_on_findings` | Fallar el workflow si hay hallazgos | No | `true` |

### Ejecución local con Docker

```bash
# Desde la raíz del repositorio cicd-security-scanner/
docker build --build-arg MODULE=sast -t cicd-sast-scanner .

# Escanear con Semgrep (default)
docker run --rm -v /path/to/repo:/scan cicd-sast-scanner

# Escanear con Bandit
docker run --rm -v /path/to/repo:/scan -e TOOL=bandit cicd-sast-scanner

# Semgrep con config específica
docker run --rm -v /path/to/repo:/scan -e SEMGREP_CONFIG=p/security-audit cicd-sast-scanner
```

## Configs de Semgrep

| Config | Descripción |
|--------|-------------|
| `auto` | Auto-detecta lenguaje y aplica reglas relevantes |
| `p/ci` | Reglas optimizadas para CI (menos falsos positivos) |
| `p/security-audit` | Auditoría de seguridad completa |
| `p/owasp-top-ten` | Vulnerabilidades OWASP Top 10 |

## Salidas

- `results.sarif` — Formato SARIF para GitHub Security tab
- Artefacto `sast-results-<sha>.sarif`
- Comentarios inline en PR

## ➕ Añadir otra herramienta SAST

1. Registrar la instalación en `shared/install-tool.sh`
2. Añadir la herramienta a `sast/tools.txt`
3. Crear `sast/scripts/scan-<tool>.sh` que genere SARIF en `$RESULTS_FILE`

## Estructura del módulo

```
sast/
├── action.yaml
├── tools.txt                 # semgrep, bandit
├── scripts/
│   ├── scan.sh               # Dispatcher
│   ├── scan-semgrep.sh       # Lógica Semgrep
│   ├── scan-bandit.sh        # Lógica Bandit
│   └── comment-findings.js   # Comentarios PR
└── README.md
```

## Licencia

MIT
