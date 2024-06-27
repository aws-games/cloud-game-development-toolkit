.DEFAULT_GOAL := help

ifeq ($(GITHUB_ACTIONS),true)
	GIT_USER_NAME := github-actions[bot]
	GIT_USER_EMAIL := "41898282+github-actions[bot]@users.noreply.github.com"
else
	GIT_USER_NAME := $(shell git config user.name)
	GIT_USER_EMAIL := $(shell git config user.email)
endif

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

.PHONY: docs-deploy-prod
docs-deploy-prod: ## Build and deploy the docs using 'mike'. Same as `docs-build` but requires PUSH_REMOTE to be explicitly set to deploy to remote branch. Usage: `make docs-deploy-prod VERSION=v1.0.0 ALIAS=latest PUSH_REMOTE=true`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'make docs-deploy-prod VERSION=v1.0.0 ALIAS=latest PUSH_REMOTE=true'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@if [ -z "${ALIAS}" ]; then echo -e "${RED}ALIAS is not set. Example: 'make docs-deploy-prod VERSION=v1.0.0 ALIAS=latest PUSH_REMOTE=true'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@if [ -z "${PUSH_REMOTE}" ]; then echo -e "${RED}PUSH_REMOTE is not set This should be "true" if deploying to prod. Example: 'make docs-deploy-prod VERSION=v1.0.0 ALIAS=latest PUSH_REMOTE=true'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "${GREEN}Docs version is: ${VERSION}:${ALIAS}${RESET}";
	@docker build -f ./docs/Dockerfile -t docs:${VERSION} -t docs:${ALIAS} . \
		--build-arg GIT_USER_NAME="${GIT_USER_NAME}" \
		--build-arg GIT_USER_EMAIL="${GIT_USER_EMAIL}" \
		--build-arg GITHUB_ACTIONS="${GITHUB_ACTIONS}" \
		--build-arg VERSION="${VERSION}" \
		--build-arg ALIAS="${ALIAS}" \
		--build-arg PUSH_REMOTE=${PUSH_REMOTE} \
		--no-cache
	
.PHONY: docs-build
docs-build: ## Build the docs locally as a container image, tagged with version and alias (ex: docs:v1.0.0, docs:latest). Usage: `make docs-build VERSION=v1.0.0 ALIAS=latest`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'docs-build VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@if [ -z "${ALIAS}" ]; then echo -e "${RED}ALIAS is not set. Example: 'docs-build VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "${GREEN}Docs version is: ${VERSION}:${ALIAS}${RESET}";
	@docker build -f ./docs/Dockerfile -t docs:${VERSION} -t docs:${ALIAS} . \
		--build-arg GIT_USER_NAME="${GIT_USER_NAME}" \
		--build-arg GIT_USER_EMAIL="${GIT_USER_EMAIL}" \
		--build-arg GITHUB_ACTIONS="${GITHUB_ACTIONS}" \
		--build-arg VERSION="${VERSION}" \
		--build-arg ALIAS="${ALIAS}" \
		--build-arg PUSH_REMOTE="false" \
		--no-cache

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