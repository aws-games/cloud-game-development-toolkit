FROM amazonlinux:2023

# Install p4broker from Perforce YUM repository
RUN rpm --import https://package.perforce.com/perforce.pubkey && \
    echo -e "[perforce]\nname=Perforce\nbaseurl=https://package.perforce.com/yum/rhel/9/x86_64\nenabled=1\ngpgcheck=1\ngpgkey=https://package.perforce.com/perforce.pubkey" \
    > /etc/yum.repos.d/perforce.repo && \
    dnf install -y helix-broker && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Create config directory
RUN mkdir -p /config /tmp

# p4broker listens on 1666 by default
EXPOSE 1666

# Run p4broker in foreground mode
ENTRYPOINT ["/usr/sbin/p4broker", "-c", "/config/p4broker.conf"]
