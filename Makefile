.DEFAULT_GOAL := help

GIT_USER_NAME := $(shell git config user.name)
GIT_USER_EMAIL := $(shell git config user.email)

# Container runtime: docker or finch (defaults to docker for external contributors)
# Internal developers can override: CONTAINER_RUNTIME=finch make docs-serve
CONTAINER_RUNTIME ?= docker

COLOR_SUPPORT := $(shell tput colors 2>/dev/null)
# Define color codes if the terminal supports color
ifdef COLOR_SUPPORT
  ifneq ($(shell tput colors),-1)
    RED := $(shell tput setaf 1)
    GREEN := $(shell tput setaf 2)
		CYAN := $(shell tput setaf 6)
    RESET := $(shell tput sgr0)
  endif
endif

.PHONY: docs-serve
# Start local docs server with live reload in container (no VERSION/ALIAS needed)
docs-serve: ## Start local docs server with live reload (use CONTAINER_RUNTIME=finch for Finch)
	@echo -e "${GREEN}Starting MkDocs development server using ${CONTAINER_RUNTIME}...${RESET}"
	@echo -e "${CYAN}Building container image...${RESET}"
	@${CONTAINER_RUNTIME} build -t cgdt-docs:dev ./docs/
	@echo -e "${GREEN}Docs available at http://127.0.0.1:8000${RESET}"
	@${CONTAINER_RUNTIME} run --rm -it -p 8000:8000 -v ${PWD}:/docs cgdt-docs:dev

.PHONY: docs-build
# Build docs locally for testing in container (no VERSION/ALIAS needed)
docs-build: ## Build docs locally for testing (use CONTAINER_RUNTIME=finch for Finch)
	@echo -e "${GREEN}Building documentation using ${CONTAINER_RUNTIME}...${RESET}"
	@${CONTAINER_RUNTIME} build -t cgdt-docs:dev ./docs/
	@${CONTAINER_RUNTIME} run --rm -v ${PWD}:/docs cgdt-docs:dev build --strict
	@echo -e "${GREEN}Documentation built successfully in ./site${RESET}"

.PHONY: docs-deploy-github
# Deploy the docs to remote branch in github.
docs-deploy-github: ## Usage: `docs-deploy-github VERSION=v1.0.0 ALIAS=latest`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'docs-deploy-github VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@if [ -z "${ALIAS}" ]; then echo -e "${RED}ALIAS is not set. Example: 'docs-deploy-github VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "${GREEN}Docs version is: ${VERSION}:${ALIAS}${RESET}";
	pip install -r ./docs/requirements.txt
	mike deploy --push --update-aliases ${VERSION} ${ALIAS}



.PHONY: help
help: ## Display this help
	@echo -e "Usage: make [TARGET]\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "${CYAN}%-30s${RESET} %s\n", $$1, $$2}'
