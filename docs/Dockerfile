FROM squidfunk/mkdocs-material
COPY ./requirements.txt requirements.txt
# Set PIP_USER to "no" to suppress warnings. Fine to run as root for local mkdocs development server.
ENV PIP_USER=no
RUN pip install -r requirements.txt