FROM squidfunk/mkdocs-material:9.7.5@sha256:c3739993c3e7c92cfe649ba03cbc04f4fa9b1497886abd16267eb413cda8aecf
COPY requirements.txt ./
ARG VERSION ALIAS
ENV VERSION=$VERSION ALIAS=$ALIAS
RUN pip install -U -r requirements.txt
WORKDIR /docs
