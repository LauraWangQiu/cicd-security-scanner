# SCA Scanner Module

Análisis de vulnerabilidades en dependencias usando [Trivy](https://github.com/aquasecurity/trivy) y [Grype](https://github.com/anchore/grype).

## Características

✅ **Dos herramientas** intercambiables: Trivy (default), Grype  
✅ Soporte multi-lenguaje (Node, Python, Java, Go, Ruby, .NET, Rust, PHP)  
✅ Detección automática de lockfiles  
✅ Modo PR: escanea solo dependencias cambiadas  
✅ Comentarios PR con resumen de vulnerabilidades  
✅ Reportes SARIF y security gate configurable  

## Herramientas

| Herramienta | Descripción |
|-------------|-------------|
| [Trivy](https://github.com/aquasecurity/trivy) | Scanner multi-propósito de Aqua Security |
| [Grype](https://github.com/anchore/grype) | Scanner de vulnerabilidades de Anchore |

Las versiones se definen en `tools.txt` y se instalan automáticamente.

## Ficheros soportados

| Lenguaje | Ficheros |
|----------|----------|
| Node.js | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` |
| Python | `requirements.txt`, `Pipfile.lock`, `poetry.lock` |
| Java | `pom.xml`, `build.gradle`, `build.gradle.kts` |
| Go | `go.sum` |
| Ruby | `Gemfile.lock` |
| .NET | `packages.lock.json`, `*.csproj` |
| Rust | `Cargo.lock` |
| PHP | `composer.lock` |

## Uso

### Como GitHub Action

```yaml
- uses: LauraWangQiu/cicd-security-scanner/sca@main
  with:
    tool: 'trivy'               # o 'grype'
    severity: 'HIGH,CRITICAL'
    scan_mode: 'full'           # o 'pr'
    fail_on_vulnerabilities: 'true'
```

### Inputs

| Input | Descripción | Requerido | Default |
|-------|-------------|-----------|---------|
| `tool` | Herramienta: `trivy`, `grype` | No | `trivy` |
| `severity` | Severidad mínima: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` | No | `HIGH,CRITICAL` |
| `scan_mode` | Modo: `full` (repo entero) o `pr` (solo dependencias cambiadas) | No | `full` |
| `base_ref` | Rama base para comparación PR diff | No | `main` |
| `fail_on_vulnerabilities` | Fallar el workflow si hay vulnerabilidades | No | `true` |

### Ejecución local con Docker

```bash
# Desde la raíz del repositorio cicd-security-scanner/
docker build --build-arg MODULE=sca -t cicd-sca-scanner .

# Escanear con Trivy (default)
docker run --rm -v /path/to/repo:/scan cicd-sca-scanner

# Escanear con Grype
docker run --rm -v /path/to/repo:/scan -e TOOL=grype cicd-sca-scanner
```

## Salidas

Cuando se detectan vulnerabilidades:

- **Artefacto** — `sca-results-<sha>` con reporte SARIF
- **Comentario PR** — Resumen con paquetes afectados
- **Workflow Failure** — Bloquea el PR (configurable)

## ➕ Añadir otra herramienta SCA

1. Registrar la instalación en `shared/install-tool.sh`
2. Añadir la herramienta a `sca/tools.txt`
3. Crear `sca/scripts/scan-<tool>.sh` que genere SARIF en `$RESULTS_FILE`

## Estructura del módulo

```
sca/
├── action.yaml
├── tools.txt                    # trivy, grype
├── scripts/
│   ├── scan.sh                  # Dispatcher
│   ├── scan-trivy.sh            # Lógica Trivy
│   ├── scan-grype.sh            # Lógica Grype
│   └── comment-vulnerabilities.js  # Comentarios PR
└── README.md
```

## Licencia

MIT
