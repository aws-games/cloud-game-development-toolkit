docs-build:
	docker build -t squidfunk/mkdocs-material ./docs/
  
docs-local-docker:
	docker build -t squidfunk/mkdocs-material ./docs/
	docker run --rm -it -p 8000:8000 -v ${PWD}:/docs squidfunk/mkdocs-material serve -a 0.0.0.0:8000

docs-deploy:
	pip install -r ./docs/requirements.txt
	mike set-default $(git rev-parse --short HEAD)
	mike deploy --push --update-aliases