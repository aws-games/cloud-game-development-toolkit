FROM squidfunk/mkdocs-material:9.8.0@sha256:dc3b5de76c6e30d18dc0922d4c4a7bed817e5e155f9ff0e594a53eb56e537e64
COPY requirements.txt ./
ARG VERSION ALIAS
ENV VERSION=$VERSION ALIAS=$ALIAS
RUN pip install -U -r requirements.txt
WORKDIR /docs
