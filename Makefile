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


.PHONY: docs-build
docs-build: ## Build the docs using docker. Example: `make docs-build VERSION=v1.0.0`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'make docs-build VERSION=v1.0.0'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "Docs version is: ${GREEN}$(VERSION)${RESET}"
	docker build -f ./docs/Dockerfile -t docs:$(VERSION) . \
		--build-arg GIT_USER_NAME="$(GIT_USER_NAME)" \
		--build-arg GIT_USER_EMAIL="$(GIT_USER_EMAIL)" \
		--build-arg GITHUB_ACTIONS="$(GITHUB_ACTIONS)" 
		--no-cache

.PHONY: docs-deploy
docs-deploy: ## Build and deploy the docs using 'mike'. Example: `make docs-deploy VERSION=v1.0.0 ALIAS=latest`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'make docs-deploy VERSION=v1.0.0'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@if [ -z "${ALIAS}" ]; then echo -e "${RED}ALIAS is not set. Example: 'make docs-deploy VERSION=v1.0.0 ALIAS=latest'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "Docs version is: ${GREEN}$(VERSION)${RESET}"
	docker build -f ./docs/Dockerfile -t docs:$(VERSION) . \
		--build-arg GIT_USER_NAME="$(GIT_USER_NAME)" \
		--build-arg GIT_USER_EMAIL="$(GIT_USER_EMAIL)" \
		--build-arg GITHUB_ACTIONS="$(GITHUB_ACTIONS)" 
		--no-cache
	docker run -t docs:$(VERSION) mike deploy $(VERSION) ${ALIAS} --update-aliases
	docker run -t docs:$(VERSION) mike set-default $(ALIAS) --push --allow-empty

.PHONY: docs-local-docker
docs-local-docker: ## Build and run the docs locally using docker and 'serve'. Example: `make docs-local-docker VERSION=v1.0.0`
	@if [ -z "${VERSION}" ]; then echo -e "${RED}VERSION is not set. Example: 'make docs-local-docker VERSION=v1.0.0'. Run 'make help' for usage. ${RESET}"; exit 1; fi
	@echo -e "Docs version is: ${GREEN}$(VERSION)${RESET}"
	docker build -f ./docs/Dockerfile -t docs:$(VERSION) . \
		--build-arg GIT_USER_NAME="$(GIT_USER_NAME)" \
		--build-arg GIT_USER_EMAIL="$(GIT_USER_EMAIL)" \
		--build-arg GITHUB_ACTIONS="$(GITHUB_ACTIONS)"
		--no-cache
	docker run --rm -it -p 8000:8000 -v ${PWD}:/docs docs:$(VERSION) mkdocs serve --dev-addr=0.0.0.0:8000

.PHONY: help
help: ## Display this help
	@echo -e "Usage: make [TARGET]\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "${CYAN}%-30s${RESET} %s\n", $$1, $$2}'