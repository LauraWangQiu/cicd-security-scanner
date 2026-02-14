# Secret Scanner Module

Detección de secretos en repositorios usando [Gitleaks](https://github.com/gitleaks/gitleaks) y [TruffleHog](https://github.com/trufflesecurity/trufflehog).

## Características

✅ **Dos herramientas** intercambiables: Gitleaks (default), TruffleHog  
✅ **Tres modos de escaneo**: PR diff, historial git, ficheros actuales  
✅ Comentarios inline en PRs con secretos detectados  
✅ Reportes SARIF compatibles con GitHub Security  
✅ Security gate: bloquea el merge si se encuentran secretos  

## Herramientas

| Herramienta | Descripción | Versión |
|-------------|-------------|---------|
| [Gitleaks](https://github.com/gitleaks/gitleaks) | Detector rápido basado en reglas regex | 8.30.0 |
| [TruffleHog](https://github.com/trufflesecurity/trufflehog) | Detector con verificación activa de credenciales | 3.93.3 |

Las versiones se definen en `tools.txt` y se instalan automáticamente.

## Modos de escaneo

| Modo | Descripción | Caso de uso |
|------|-------------|-------------|
| `pr` | Escanea solo ficheros cambiados en PR | CI/CD en Pull Requests |
| `history` | Escanea todo el historial de commits | Auditoría completa del repositorio |
| `files` | Escanea ficheros actuales en disco | Testing local, incluye cambios sin commit |
| `auto` | Auto-detecta (PR en CI, files localmente) | Comportamiento por defecto |

## Uso

### Como GitHub Action

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
        uses: LauraWangQiu/cicd-security-scanner/secrets@main
        with:
          tool: 'gitleaks'      # o 'trufflehog'
          scan_mode: 'auto'
          base_ref: main
```

### Inputs

| Input | Descripción | Requerido | Default |
|-------|-------------|-----------|---------|
| `tool` | Herramienta: `gitleaks`, `trufflehog` | No | `gitleaks` |
| `base_ref` | Rama base para comparación | No | `main` |
| `scan_mode` | Modo: `pr`, `history`, `files`, `auto` | No | `auto` |

### Ejecución local con Docker

```bash
# Desde la raíz del repositorio cicd-security-scanner/
docker build --build-arg MODULE=secrets -t cicd-secret-scanner .

# Escanear ficheros actuales (default)
docker run --rm -v /path/to/repo:/scan cicd-secret-scanner

# Escanear con TruffleHog
docker run --rm -v /path/to/repo:/scan -e TOOL=trufflehog cicd-secret-scanner

# Escanear historial de commits
docker run --rm -v /path/to/repo:/scan -e SCAN_MODE=history cicd-secret-scanner
```

**Windows PowerShell:**
```powershell
docker run --rm -v C:\path\to\repo:/scan cicd-secret-scanner
docker run --rm -v C:\path\to\repo:/scan -e SCAN_MODE=history cicd-secret-scanner
```

## Salidas

Cuando se detectan secretos:

- **Artefacto** — `secrets-<modo>-results-<sha>` con reporte SARIF
- **Comentarios PR** — Comentarios inline en las líneas afectadas
- **Workflow Failure** — Bloquea el PR con mensaje de error

## ➕ Añadir otra herramienta de secretos

Para añadir una nueva herramienta (ej: `detect-secrets`):

1. Registrar la instalación en `shared/install-tool.sh` (un `case` con el comando de instalación)
2. Añadir `detect-secrets <version>` a `secrets/tools.txt`
3. Crear `secrets/scripts/scan-detect-secrets.sh` que genere SARIF en `$RESULTS_FILE`

No hay que tocar el Dockerfile, ni `scan.sh`, ni `action.yaml`.

## Estructura del módulo

```
secrets/
├── action.yaml              # Definición de la GitHub Action
├── tools.txt                 # Herramientas a instalar (gitleaks, trufflehog)
├── scripts/
│   ├── scan.sh               # Dispatcher (auto-dispatch por $TOOL)
│   ├── scan-gitleaks.sh      # Lógica de escaneo con Gitleaks
│   ├── scan-trufflehog.sh    # Lógica de escaneo con TruffleHog
│   └── comment-secrets.js    # Generador de comentarios PR
└── README.md
```

## Troubleshooting

**Los secretos que deberían detectarse no aparecen**
- Verifica tu `.gitleaks.toml` en el repositorio
- Asegúrate de que los patrones están habilitados
- Prueba con `SCAN_MODE=history` para buscar en todo el historial

## Licencia

MIT

## Privacidad & Seguridad

Esta Action:  
✅ Solo lee el diff del PR (no se recopilan datos personales)  
✅ No se almacena ni transmite información externamente  
✅ Cumple con GDPR  
✅ Código abierto y auditable

## Soporte

Issues: [GitHub Issues](https://github.com/LauraWangQiu/cicd-security-scanner/issues)  
Email: yiwang03@ucm.es | lauraonetwo443@gmail.com
