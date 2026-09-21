FROM squidfunk/mkdocs-material:9.7.7@sha256:51b87149d227691486b5f08993d28c65ca7e4990010664b697265b8e6fcd5287
COPY requirements.txt ./
ARG VERSION ALIAS
ENV VERSION=$VERSION ALIAS=$ALIAS
RUN pip install -U -r requirements.txt
WORKDIR /docs
