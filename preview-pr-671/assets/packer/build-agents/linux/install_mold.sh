#!/usr/bin/env bash
# Install the mold linker on Linux (any OS), architecture-independent
# Requires common tools to be installed first.
echo "Installing mold..."
curl -s -L https://github.com/rui314/mold/releases/download/v2.31.0/mold-2.31.0-$(uname -m)-linux.tar.gz | sudo tar -xvzf - --strip-components=1 -C /usr
