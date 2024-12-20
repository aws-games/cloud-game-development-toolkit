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

.PHONY: docs-deploy-github
# Deploy the docs to remote branch in github. 
docs-deploy-github: ## Usage: `docs-deploy-github VERSION=v1.0.0 ALIAS=latest`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'docs-deploy-github VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@if [ -z "${ALIAS}" ]; then echo -e "${RED}ALIAS is not set. Example: 'docs-deploy-github VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "${GREEN}Docs version is: ${VERSION}:${ALIAS}${RESET}";
	pip install -r ./docs/requirements.txt
	mike deploy --push --update-aliases ${VERSION} ${ALIAS}

.PHONY: docs-run
# Builds and runs a specific version of the docs in Docker with live reloading to support iterative development. This doesn't include the version selector in the navigation pane that ships in production.
docs-run: ## Usage: `make docs-run VERSION=v1.0.0 ALIAS=latest`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'make docs-run VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@if [ -z "${ALIAS}" ]; then echo -e "${RED}ALIAS is not set. Example: 'make docs-run VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "${GREEN}Docs version is: ${VERSION}:${ALIAS}${RESET}";
	docker build -t docs:${VERSION} ./docs/
	docker run --rm -it -p 8000:8000 -v ${PWD}:/docs docs:${VERSION}

.PHONY: docs-run-versioned
# Builds and runs the docs in Docker using `mike` instead of `mkdocs` to run a versioned docs site locally (what we deploy to prod). `mike` doesn't support live reloading, so you'll need to rebuild the container to see changes.
docs-run-versioned: ## Usage: `make docs-run-versioned VERSION=v1.0.0 ALIAS=latest`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'make docs-run-versioned VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@if [ -z "${ALIAS}" ]; then echo -e "${RED}ALIAS is not set. Example: 'make docs-run-versioned VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "${GREEN}Docs version is: ${VERSION}:${ALIAS}${RESET}";
	docker build -t docs:${VERSION} ./docs/
	docker run --rm -it -p 8000:8000 -v ${PWD}:/docs --entrypoint /bin/sh docs:${VERSION} -c "mike serve --dev-addr=0.0.0.0:8000"

.PHONY: help
help: ## Display this help
	@echo -e "Usage: make [TARGET]\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "${CYAN}%-30s${RESET} %s\n", $$1, $$2}'
