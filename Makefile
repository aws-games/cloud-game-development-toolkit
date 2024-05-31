docs-local-docker:
	docker build -t squidfunk/mkdocs-material ./docs/
	docker run --rm -it -p 8000:8000 -v ${PWD}:/docs squidfunk/mkdocs-material
