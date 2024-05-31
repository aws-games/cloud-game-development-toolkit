dev:
	pip install pre-commit poetry
	poetry config --local virtualenvs.in-project true
	poetry install
	pre-commit install

docs-local-docker:
	docker build -t squidfunk/mkdocs-material ./docs/
	docker run --rm -it -p 8000:8000 -v ${PWD}:/docs squidfunk/mkdocs-material
