FROM squidfunk/mkdocs-material:9.6.7
COPY requirements.txt ./
ARG VERSION ALIAS
ENV VERSION=$VERSION ALIAS=$ALIAS
RUN pip install -U -r requirements.txt
WORKDIR /docs