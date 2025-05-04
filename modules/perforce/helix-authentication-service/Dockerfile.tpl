FROM ${image}:${tag}
ENV MY_TEST_VAR=HelloFromDockerfile
RUN echo $MY_TEST_VAR