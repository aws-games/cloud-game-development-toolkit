.DEFAULT_GOAL := help

GIT_USER_NAME := $(shell git config user.name)
GIT_USER_EMAIL := $(shell git config user.email)

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
		
.PHONY: docs-build-local
docs-build-local: ## Build the docs to run locally as a container image, tagged with version and alias (ex: docs:v1.0.0, docs:latest). Usage: `make docs-build-local VERSION=v1.0.0 ALIAS=latest`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'docs-build-local VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@if [ -z "${ALIAS}" ]; then echo -e "${RED}ALIAS is not set. Example: 'docs-build-local VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "${GREEN}Docs version is: ${VERSION}:${ALIAS}${RESET}";
	@docker build -f ./docs/Dockerfile -t docs:${VERSION} -t docs:${ALIAS} . \
		--build-arg GIT_USER_NAME="${GIT_USER_NAME}" \
		--build-arg GIT_USER_EMAIL="${GIT_USER_EMAIL}" \
		--build-arg VERSION="${VERSION}" \
		--build-arg ALIAS="${ALIAS}" \
		--no-cache

.PHONY: docs-install-dependencies
docs-install-dependencies: ## Install dependencies required for the docs. Usage: `make docs-install-dependencies VERSION=v1.0.0 ALIAS=latest`
	pip install -r ./docs/requirements.txt 

.PHONY: docs-deploy-github
docs-deploy-github: ## Deploy the docs to remote branch in github. Usage: `docs-deploy-github VERSION=v1.0.0 ALIAS=latest`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'docs-deploy-github VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@if [ -z "${ALIAS}" ]; then echo -e "${RED}ALIAS is not set. Example: 'docs-deploy-github VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "${GREEN}Docs version is: ${VERSION}:${ALIAS}${RESET}";
	mike deploy --push --update-aliases ${VERSION} ${ALIAS}

.PHONY: docs-run
docs-run: ## Run a built docs container image locally. Usage: `make docs-run VERSION=v1.0.0 ALIAS=latest`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'make docs-run VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@if [ -z "${ALIAS}" ]; then echo -e "${RED}ALIAS is not set. Example: 'make docs-run VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "${GREEN}Docs version is: ${VERSION}:${ALIAS}${RESET}";
	@CONTAINERS=$(shell docker ps -q -f publish=8000) && if [ -n "$$CONTAINERS" ]; then echo -e "${GREEN}Clearing port 8000 and running docs locally. Waiting...${RESET}"; docker stop $$CONTAINERS; fi
	@docker run -d -p 8000:8000 docs:${VERSION} mike serve --dev-addr=0.0.0.0:8000
	@echo -e "${GREEN}Docs running at: http://localhost:8000${RESET}"

.PHONY: help
help: ## Display this help
	@echo -e "Usage: make [TARGET]\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "${CYAN}%-30s${RESET} %s\n", $$1, $$2}'