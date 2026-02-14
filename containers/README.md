# Container Scanner Module

Escaneo de vulnerabilidades en imágenes Docker usando [Trivy](https://github.com/aquasecurity/trivy) y [Grype](https://github.com/anchore/grype).

## Características

✅ **Dos herramientas** intercambiables: Trivy (default), Grype  
✅ Escanea imágenes Docker para vulnerabilidades OS y aplicación (CVEs)  
✅ Auto-descubrimiento de Dockerfiles: construye y escanea las imágenes  
✅ Modo PR: solo escanea Dockerfiles cambiados  
✅ Escaneo de imagen explícita (`image: nginx:latest`)  
✅ Fallback a escaneo de misconfiguraciones si no hay Dockerfiles  
✅ Merge de resultados SARIF cuando hay múltiples Dockerfiles  

## Herramientas

| Herramienta | Descripción |
|-------------|-------------|
| [Trivy](https://github.com/aquasecurity/trivy) | Scanner multi-propósito de Aqua Security |
| [Grype](https://github.com/anchore/grype) | Scanner de vulnerabilidades de Anchore |

Las versiones se definen en `tools.txt` y se instalan automáticamente.

## Uso

### Escanear una imagen específica

```yaml
- uses: LauraWangQiu/cicd-security-scanner/containers@main
  with:
    tool: 'trivy'                # o 'grype'
    image: 'nginx:latest'
    severity: 'HIGH,CRITICAL'
    fail_on_vulnerabilities: 'true'
```

### Escanear Dockerfiles del repositorio

```yaml
- uses: LauraWangQiu/cicd-security-scanner/containers@main
  # Sin image = descubre Dockerfiles, construye y escanea
```

### Inputs

| Input | Descripción | Requerido | Default |
|-------|-------------|-----------|---------|
| `tool` | Herramienta: `trivy`, `grype` | No | `trivy` |
| `image` | Imagen a escanear (ej: `nginx:latest`) | No | _(auto-descubre Dockerfiles)_ |
| `severity` | Severidad mínima: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` | No | `HIGH,CRITICAL` |
| `scan_mode` | Modo: `full` (todo el repo) o `pr` (solo Dockerfiles cambiados) | No | `full` |
| `base_ref` | Rama base para comparación PR diff | No | `main` |
| `fail_on_vulnerabilities` | Fallar el workflow si hay vulnerabilidades | No | `true` |

### Ejecución local con Docker

```bash
# Desde la raíz del repositorio cicd-security-scanner/
docker build --build-arg MODULE=containers -t cicd-container-scanner .

# Escanear una imagen específica
docker run --rm \
  -v $(pwd):/scan \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e IMAGE=nginx:latest \
  cicd-container-scanner

# Escanear Dockerfiles del repo (construye + escanea)
docker run --rm \
  -v $(pwd):/scan \
  -v /var/run/docker.sock:/var/run/docker.sock \
  cicd-container-scanner

# Con Grype en vez de Trivy
docker run --rm \
  -v $(pwd):/scan \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e TOOL=grype \
  cicd-container-scanner
```

## Flujo de escaneo

1. Si se proporciona `IMAGE` → escanea esa imagen directamente
2. Si no → descubre Dockerfiles en el repo (o solo los cambiados en modo PR)
3. Construye una imagen por cada Dockerfile encontrado
4. Escanea cada imagen construida
5. Merge de todos los resultados SARIF en un único `results.sarif`
6. Limpia las imágenes construidas

## Qué detecta

| Categoría | Ejemplos |
|----------|----------|
| Vulnerabilidades OS | CVEs en paquetes Alpine, Debian, Ubuntu |
| Vulnerabilidades de aplicación | CVEs en dependencias Python, Node.js, Java |
| Misconfiguraciones Dockerfile | Ejecutar como root, falta HEALTHCHECK, etc. |
| Imágenes base obsoletas | Uso de imágenes base vulnerables/antiguas |

## Salidas

- `results.sarif` — Formato SARIF para GitHub Security tab
- Artefacto `container-results-<sha>.sarif`
- Comentarios inline en PR

## ➕ Añadir otra herramienta de containers

1. Registrar la instalación en `shared/install-tool.sh`
2. Añadir la herramienta a `containers/tools.txt`
3. Crear `containers/scripts/scan-<tool>.sh` que defina `scan_image()` y use las helpers compartidas

## Estructura del módulo

```
containers/
├── action.yaml
├── tools.txt                 # trivy, grype, docker-cli
├── scripts/
│   ├── scan.sh               # Dispatcher
│   ├── scan-trivy.sh         # Lógica Trivy (imagen + config)
│   ├── scan-grype.sh         # Lógica Grype (imagen + filesystem)
│   └── comment-findings.js   # Comentarios PR
└── README.md
```

## Licencia

MIT
