FROM squidfunk/mkdocs-material:9.7.2@sha256:1c30983ef0681684d07a90f4f34a2ff8adf7aaa0bfc1c0d518873bb5e7912f37
COPY requirements.txt ./
ARG VERSION ALIAS
ENV VERSION=$VERSION ALIAS=$ALIAS
RUN pip install -U -r requirements.txt
WORKDIR /docs
