FROM squidfunk/mkdocs-material:9.7.3@sha256:8f41b6089700e1c32212c3857936f14e88a3306a35be4ffd1826420e2f3e4197
COPY requirements.txt ./
ARG VERSION ALIAS
ENV VERSION=$VERSION ALIAS=$ALIAS
RUN pip install -U -r requirements.txt
WORKDIR /docs
