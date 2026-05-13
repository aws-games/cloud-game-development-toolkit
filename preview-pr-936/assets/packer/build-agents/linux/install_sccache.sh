#!/usr/bin/env bash
# Install sccache on Linux (any OS), architecture-independent
# Requires common tools to be installed first.
# This script does not set up a service or anything to automatically start it!
cd $(mktemp -d)
curl -s -L "https://github.com/mozilla/sccache/releases/download/v0.5.3/sccache-v0.5.3-$(uname -m)-unknown-linux-musl.tar.gz" | tar xvzf -
sudo cp sccache*/sccache /usr/bin/
