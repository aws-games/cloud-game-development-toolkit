FROM squidfunk/mkdocs-material:9.7.6@sha256:868ad4d39fb5865b72d00173ade00f4eae2b38dde7ff790a011cc44ce4a8ff8e
COPY requirements.txt ./
ARG VERSION ALIAS
ENV VERSION=$VERSION ALIAS=$ALIAS
RUN pip install -U -r requirements.txt
WORKDIR /docs
