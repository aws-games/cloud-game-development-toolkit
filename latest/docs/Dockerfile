FROM squidfunk/mkdocs-material:9.7.0@sha256:980e11fed03b8e7851e579be9f34b1210f516c9f0b4da1a1457f21a460bd6628
COPY requirements.txt ./
ARG VERSION ALIAS
ENV VERSION=$VERSION ALIAS=$ALIAS
RUN pip install -U -r requirements.txt
WORKDIR /docs
