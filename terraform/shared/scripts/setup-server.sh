#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

set -e

# Set up the server
while pgrep -u root 'apt|dpkg' >/dev/null; do
  sleep 10
done

echo 
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install -y ec2-instance-connect awscli net-tools

sudo mkdir /opt/consul/logs
sudo mkdir /opt/nomad/logs
sudo mkdir /opt/vault/logs
sudo mkdir -p /opt/acl
sudo mkdir -p /opt/licenses
sudo chown -R consul:ubuntu ./consul
sudo chown -R nomad:ubuntu ./nomad
sudo chown -R vault:ubuntu ./vault
sudo chmod -R 755 /opt/consul
sudo chmod -R 755 /opt/nomad
sudo chmod -R 755 /opt/vault
sudo find /opt -type d -exec chmod g+s {} \;
sudo chmod -R g+rX /opt

echo "alias env='env -0 | sort -z | tr '\\0' '\\n''" >> ~/.bashrc
echo "export AWS_DEFAULT_REGION=\$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')" >> ~/.bashrc
echo "export INSTANCE_NAME=\$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/Name)" >> ~/.bashrc
echo "export PROMPTID=\$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/PromptID)" >> ~/.bashrc
echo "export PUBIP=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" >> ~/.bashrc
echo "export PRIIP=\$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)" >> ~/.bashrc
echo 'if [[ $TERM_PROGRAM == "WarpTerminal" ]]; then
  PS1="\\[\\033[0;33m\\](\$PROMPTID)[Int: \$PRIIP / Ext: \$PUBIP] \\[\\033[01;32m\\]\\u\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ "
else
  PS1="\\[\\033[0;33m\\](\$PROMPTID)[Int: \$PRIIP / Ext: \$PUBIP]\\[\\033[0m\\]\\n\\[\\033[01;32m\\]\\u\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ "
fi' >> ~/.bashrc

source ~/.bashrc
