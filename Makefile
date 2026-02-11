## Makefile for building scanner images
# Usage:
#   make secrets      # build secrets scanner image
#   make sast         # build sast scanner image
#   make sca          # build sca scanner image
#   make iac          # build iac scanner image
#   make containers   # build container scanner image
#   make all          # build all images

DOCKER=docker

SECRETS_DIR=secrets
SAST_DIR=sast
SCA_DIR=sca
IAC_DIR=iac
CONTAINERS_DIR=containers

.PHONY: all secrets sast sca iac containers help

all: secrets sast sca iac containers

secrets:
	@echo "Building cicd-secret-scanner..."
	$(DOCKER) build -t cicd-secret-scanner ./$(SECRETS_DIR)

sast:
	@echo "Building cicd-sast-scanner..."
	$(DOCKER) build -t cicd-sast-scanner ./$(SAST_DIR)

sca:
	@echo "Building cicd-sca-scanner..."
	$(DOCKER) build -t cicd-sca-scanner ./$(SCA_DIR)

iac:
	@echo "Building cicd-iac-scanner..."
	$(DOCKER) build -t cicd-iac-scanner ./$(IAC_DIR)

containers:
	@echo "Building cicd-container-scanner..."
	$(DOCKER) build -t cicd-container-scanner ./$(CONTAINERS_DIR)

help:
	@echo "Makefile targets:"
	@echo "  make secrets      # build secrets scanner image"
	@echo "  make sast         # build sast scanner image"
	@echo "  make sca          # build sca scanner image"
	@echo "  make iac          # build iac scanner image"
	@echo "  make containers   # build container scanner image"
	@echo "  make all          # build all images"
