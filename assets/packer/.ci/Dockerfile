FROM ubuntu:latest

# Build arguments
ARG AWS_REGION
ARG AWS_VPC_ID
ARG AWS_SUBNET_ID
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_SESSION_TOKEN
ARG PUBLIC_KEY
ARG TEMPLATE

# Install updates and tools
RUN apt-get update -y && apt-get install -y \
    python3 \
    python3-pip \
    wget \
    unzip \
    curl \
    jq

# Download and install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && aws --version

# Download and install the latest version of Packer
RUN PACKER_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/packer | jq -r -M '.current_version') \
    && wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip \
    && unzip packer_${PACKER_VERSION}_linux_amd64.zip \
    && mv packer /usr/local/bin \
    && rm packer_${PACKER_VERSION}_linux_amd64.zip

# Copy packer directory to the container
WORKDIR / 
COPY . /cloud-game-development-toolkit

# Create Packer variables file
WORKDIR /cloud-game-development-toolkit
RUN chmod +x .ci/setup.sh && .ci/setup.sh
RUN cat << EOF > ci.pkrvars.hcl \
    region = "${AWS_REGION}" \
    vpc_id = "${AWS_VPC_ID}" \
    subnet_id = "${AWS_SUBNET_ID}" \
    profile = "${AWS_PROFILE}" \
    public_key = "${PUBLIC_KEY}" \
    EOF

# Validate the Packer template files
WORKDIR /cloud-game-development-toolkit
RUN packer init ${TEMPLATE}
RUN packer validate ${TEMPLATE}
#RUN packer build ${TEMPLATE}