FROM python:3.13.0
WORKDIR /build
COPY . . 
ARG VERSION ALIAS
ENV VERSION=$VERSION ALIAS=$ALIAS
RUN git config --global user.name "$GIT_USER_NAME" && git config --global user.email "$GIT_USER_EMAIL"
RUN make docs-install-dependencies
RUN mike deploy --update-aliases ${VERSION} ${ALIAS}
CMD ["sh", "-c"]