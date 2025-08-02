#!/usr/bin/env bash
# Compile and octobuild on Amazon Linux 2023, x86_64 only
#  (not tested on aarch64 at the moment)
# Requires common tools to be installed first.
# Will install Rust and cargo as well
sudo yum update -y
echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"
cd $(mktemp -d)
git clone https://github.com/octobuild/octobuild.git .
cargo install --path .
