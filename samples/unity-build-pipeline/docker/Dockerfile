# Unity + TeamCity Build Agent
# Combines GameCI Unity Editor with TeamCity Agent capabilities

# Start with GameCI Unity 6 base image
# Using linux-il2cpp variant which includes base Unity + Linux build support
FROM unityci/editor:ubuntu-6000.0.19f1-linux-il2cpp-3.1

# Switch to root for installations
USER root

# Install TeamCity agent dependencies
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    wget \
    curl \
    git \
    git-lfs \
    unzip \
    ca-certificates \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Set Java environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# Install Perforce P4 CLI (for checking out code)
# Using direct binary download for better compatibility
RUN wget https://filehost.perforce.com/perforce/r25.1/bin.linux26x86_64/p4 -O /usr/local/bin/p4 && \
    chmod +x /usr/local/bin/p4

# TeamCity agent environment variables
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

# Switch to buildagent user
USER buildagent
WORKDIR /opt/buildAgent

# Expose TeamCity agent port
EXPOSE 9090

# Start TeamCity agent
ENTRYPOINT ["/opt/buildAgent/teamcity-agent-startup.sh"]
