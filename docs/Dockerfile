FROM python:3.12
WORKDIR /build
COPY . . 
ARG GIT_USER_NAME GIT_USER_EMAIL GITHUB_ACTIONS VERSION ALIAS PUSH_REMOTE=false
ENV GIT_USER_NAME=$GIT_USER_NAME GIT_USER_EMAIL=$GIT_USER_EMAIL GITHUB_ACTIONS=$GITHUB_ACTIONS VERSION=$VERSION ALIAS=$ALIAS PUSH_REMOTE=$PUSH_REMOTE
RUN git config --global user.name "$GIT_USER_NAME" && git config --global user.email "$GIT_USER_EMAIL"
RUN pip install -r ./docs/requirements.txt
RUN \
  if [ "PUSH_REMOTE" = "true" ]; then export MIKE_PUSH_FLAG="--push"; else export MIKE_PUSH_FLAG=""; fi && \
  mike deploy ${MIKE_PUSH_FLAG} --update-aliases ${VERSION} ${ALIAS}
CMD ["sh", "-c"]