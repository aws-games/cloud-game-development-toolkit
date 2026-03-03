FROM squidfunk/mkdocs-material:9.7.4@sha256:f4332a8e8895aa303bf7f3ceede749980a98cf79f5d87ad567b4d41f037b0101
COPY requirements.txt ./
ARG VERSION ALIAS
ENV VERSION=$VERSION ALIAS=$ALIAS
RUN pip install -U -r requirements.txt
WORKDIR /docs
