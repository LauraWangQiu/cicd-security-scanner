# cicd-security-scanner

> “Gitleaks analiza tanto el estado actual del repositorio como su historial de commits, permitiendo detectar secretos presentes en la última versión del código y aquellos que hayan sido eliminados pero expuestos previamente.”

Para usarlo en GitHub con GitHub Actions:

1. Añade tanto el Dockerfile como el scan.sh en la raíz del repositorio a escanear
2. Añade secrets.yml en .github/workflows/ del repositorio

Para usarlo en local clonado este repositorio:

Requisitos:

- docker

1. Añade tanto el Dockerfile como el scan.sh en la raíz del repositorio a escanear
2. Construye la imagen con docker:

  ```bash
  docker build -t cicd-security-scanner .
  ```

3. Corre un container con esa imagen construida:

  Windows

  ```bash
  docker run --rm `
    -v <ruta_al_repositorio_a_escanear>:/scan `
    cicd-security-scanner
  ```

  Linux / MacOS

  ```zsh
  docker run --rm \
    -v "<ruta_al_repositorio_a_escanear>":/scan \
    cicd-security-scanner
  ```
