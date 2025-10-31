# Unity + TeamCity Build Agent
# Uses official Unity Hub and Unity Editor installations
# Incorporates best practices from GameCI for Unity containerization

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set locale for proper character encoding
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Define Unity installation path
ENV UNITY_PATH=/opt/unity

# Install system dependencies required by Unity and TeamCity
RUN apt-get update && apt-get install -y \
    # Core Unity runtime dependencies (from GameCI)
    libasound2 \
    libcap2 \
    libgconf-2-4 \
    libglu1 \
    libgtk-3-0 \
    libncurses5 \
    libnotify4 \
    libnss3 \
    libxtst6 \
    libxss1 \
    # X11 support for headless operation
    libx11-6 \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    xvfb \
    # System utilities
    ca-certificates \
    cpio \
    lsb-release \
    xz-utils \
    # Unity Hub dependencies
    wget \
    # TeamCity and build tools
    openjdk-17-jdk \
    curl \
    git \
    git-lfs \
    unzip \
    zip \
    jq \
    openssh-client \
    # Utilities
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Git LFS system-wide installation
RUN git lfs install --system

# Disable sound card (headless environment)
RUN echo "pcm.!default { type plug slave.pcm \"null\" }" > /etc/asound.conf

# Create machine-id for Unity activation
RUN rm -f /etc/machine-id && \
    dbus-uuidgen > /etc/machine-id && \
    chmod 444 /etc/machine-id

# Set Java environment variables for TeamCity
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# Install Unity Hub
# Unity Hub is the official tool for managing Unity Editor installations
ARG UNITY_HUB_VERSION=3.9.1
RUN wget -q https://hub.unity3d.com/linux/repos/deb/pool/main/u/unity/unihub_amd64/unityhub_${UNITY_HUB_VERSION}_amd64.deb \
    -O /tmp/unityhub.deb && \
    dpkg -i /tmp/unityhub.deb && \
    rm /tmp/unityhub.deb

# Install Unity Editor via Unity Hub
# Default to Unity 6 LTS - users can override with --build-arg
ARG UNITY_VERSION=6000.0.23f1
ARG UNITY_CHANGESET=bd20d88e54b8

# Install Unity Editor with Linux build support
# Using xvfb-run to provide virtual display for headless installation
RUN xvfb-run --auto-servernum --server-args='-screen 0 640x480x24' \
    unityhub --headless install \
    --version ${UNITY_VERSION} \
    --changeset ${UNITY_CHANGESET} \
    --module linux-il2cpp

# Install AWS CLI v2 for artifact management
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Install Perforce P4 CLI for source control
RUN wget -q https://filehost.perforce.com/perforce/r25.1/bin.linux26x86_64/p4 \
    -O /usr/local/bin/p4 && \
    chmod +x /usr/local/bin/p4

# TeamCity agent configuration
ENV TEAMCITY_SERVER_URL=""
ENV AGENT_NAME="unity-builder"
ENV AGENT_WORK_DIR="/opt/buildAgent/work"

# Create buildagent user and directories
RUN useradd -m -d /opt/buildAgent -s /bin/bash buildagent && \
    mkdir -p /opt/buildAgent/work /opt/buildAgent/temp /opt/buildAgent/tools /opt/buildAgent/plugins && \
    chown -R buildagent:buildagent /opt/buildAgent

# Copy startup script
COPY teamcity-agent-startup.sh /opt/buildAgent/
RUN chmod +x /opt/buildAgent/teamcity-agent-startup.sh && \
    chown buildagent:buildagent /opt/buildAgent/teamcity-agent-startup.sh

# Switch to buildagent user for running the agent
USER buildagent
WORKDIR /opt/buildAgent

# Expose TeamCity agent port (optional - agents typically connect outbound)
EXPOSE 9090

# Start TeamCity agent
ENTRYPOINT ["/opt/buildAgent/teamcity-agent-startup.sh"]
