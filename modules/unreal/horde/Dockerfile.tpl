FROM ${base_image}
ENV MY_TEST_VAR=HelloFromDockerfile
RUN echo $MY_TEST_VAR
