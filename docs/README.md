# Docs

Docs for this project are created using [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/).

The `/docs` directory contains a Dockerfile to simplify local build and test of the documentation and to support including any markdown extensions that are not included in the base mkdocs-material Docker image. 

1. Build the docker image
  - `docker build -t squidfunk/mkdocs-material .`

2. Run it locally from project root directory.
- `cd ..`
- `docker run --rm -it -p 8000:8000 -v ${PWD}:/docs squidfunk/mkdocs-material`