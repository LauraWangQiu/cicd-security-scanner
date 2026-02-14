## Makefile for building scanner images
# Usage:
#   make secrets      # build secrets scanner image
#   make sast         # build sast scanner image
#   make sca          # build sca scanner image
#   make iac          # build iac scanner image
#   make containers   # build container scanner image
#   make all          # build all images

DOCKER=docker

.PHONY: all secrets sast sca iac containers help

all: secrets sast sca iac containers

secrets:
	@echo "Building cicd-secret-scanner..."
	$(DOCKER) build --build-arg MODULE=secrets -t cicd-secret-scanner .

sast:
	@echo "Building cicd-sast-scanner..."
	$(DOCKER) build --build-arg MODULE=sast -t cicd-sast-scanner .

sca:
	@echo "Building cicd-sca-scanner..."
	$(DOCKER) build --build-arg MODULE=sca -t cicd-sca-scanner .

iac:
	@echo "Building cicd-iac-scanner..."
	$(DOCKER) build --build-arg MODULE=iac -t cicd-iac-scanner .

containers:
	@echo "Building cicd-container-scanner..."
	$(DOCKER) build --build-arg MODULE=containers -t cicd-container-scanner .

help:
	@echo "Makefile targets:"
	@echo "  make secrets      # build secrets scanner image"
	@echo "  make sast         # build sast scanner image"
	@echo "  make sca          # build sca scanner image"
	@echo "  make iac          # build iac scanner image"
	@echo "  make containers   # build container scanner image"
	@echo "  make all          # build all images"
