FROM python:3.12
WORKDIR /build
COPY . . 
ARG GIT_USER_NAME GIT_USER_EMAIL GITHUB_ACTIONS
ENV GIT_USER_NAME=$GIT_USER_NAME GIT_USER_EMAIL=$GIT_USER_EMAIL GITHUB_ACTIONS=$GITHUB_ACTIONS

RUN git config --global user.name "$GIT_USER_NAME" && git config --global user.email "$GIT_USER_EMAIL"
#RUN git config --global --add safe.directory /build
RUN pip install -r ./docs/requirements.txt --no-cache-dir
