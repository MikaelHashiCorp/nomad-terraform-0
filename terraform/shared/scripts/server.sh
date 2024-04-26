#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1


set -e

CONFIGDIR=/ops/shared/config

CONSULCONFIGDIR=/etc/consul.d
VAULTCONFIGDIR=/etc/vault.d
NOMADCONFIGDIR=/etc/nomad.d
CONSULTEMPLATECONFIGDIR=/etc/consul-template.d
HOME_DIR=ubuntu

# Wait for network
sleep 15

DOCKER_BRIDGE_IP_ADDRESS=(`ifconfig docker0 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`)
CLOUD=$1
SERVER_COUNT=$2
RETRY_JOIN=$3
NOMAD_BINARY=$4

# Get IP from metadata service
if [ "$CLOUD" = "gce" ]; then
  IP_ADDRESS=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
else
  IP_ADDRESS=$(curl http://instance-data/latest/meta-data/local-ipv4)
fi

if [ "$CLOUD" = "aws" ]; then
  while pgrep -u root 'apt|dpkg' >/dev/null; do
    sleep 10
  done
  sudo apt-get update
  sudo apt-get upgrade
  sudo apt-get install -y ec2-instance-connect awscli net-tools
  sudo find /opt -type d -exec chmod g+s {} \;

  sudo mkdir /opt/consul/logs
  sudo mkdir /opt/nomad/logs
  sudo mkdir /opt/vault/logs
  sudo chown -R consul:ubuntu ./consul
  sudo chown -R nomad:ubuntu ./nomad
  sudo chown -R vault:ubuntu ./vault
  sudo chmod -R 755 opt/consul
  sudo chmod -R 755 opt/nomad
  sudo chmod -R 755 opt/vault
  sudo find /opt -type d -exec chmod g+s {} \;
  sudo chown -R root:ubuntu /opt
  sudo chmod -R g+rX /opt
  
  echo "alias env="env -0 | sort -z | tr '\\0' '\\n'"" >> ~/.bashrc
  if ! grep -Fxq 'PS1=\"$PROMPTID)[Int:\"' ~/.bashrc ; then
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
  fi
fi

# Consul
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIGDIR/consul_server.hcl
sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" $CONFIGDIR/consul_server.hcl
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIGDIR/consul_server.hcl
sudo cp $CONFIGDIR/consul_server.hcl $CONSULCONFIGDIR

sudo systemctl enable consul.service --now
sleep 10
export CONSUL_HTTP_ADDR=$IP_ADDRESS:8500
export CONSUL_RPC_ADDR=$IP_ADDRESS:8400

# Vault
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIGDIR/vault.hcl
sudo cp $CONFIGDIR/vault.hcl $VAULTCONFIGDIR
sudo systemctl enable vault.service --now

# Nomad

# ## Replace existing Nomad binary if remote file exists
if [[ `wget -S --spider $NOMAD_BINARY  2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then
  curl -L $NOMAD_BINARY > nomad.zip
  sudo unzip -o nomad.zip -d /usr/bin/
  sudo chmod 0755 /usr/bin/nomad
  sudo chown root:root /usr/bin/nomad
fi

sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" $CONFIGDIR/nomad.hcl
sudo cp $CONFIGDIR/nomad.hcl $NOMADCONFIGDIR

sudo systemctl enable nomad.service --now
sleep 10
export NOMAD_ADDR=http://$IP_ADDRESS:4646

# Consul Template
sudo cp $CONFIGDIR/consul-template.hcl $CONSULTEMPLATECONFIGDIR/consul-template.hcl
sudo cp $CONFIGDIR/consul-template.service /etc/systemd/system/consul-template.service

# Add hostname to /etc/hosts

echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# Add Docker bridge network IP to /etc/resolv.conf (at the top)

echo "nameserver $DOCKER_BRIDGE_IP_ADDRESS" | sudo tee /etc/resolv.conf.new
cat /etc/resolv.conf | sudo tee --append /etc/resolv.conf.new
sudo mv /etc/resolv.conf.new /etc/resolv.conf

# Move examples directory to $HOME
sudo mv /ops/examples /home/$HOME_DIR
sudo chown -R $HOME_DIR:$HOME_DIR /home/$HOME_DIR/examples
sudo chmod -R 775 /home/$HOME_DIR/examples

# Set env vars for tool CLIs
echo "export CONSUL_RPC_ADDR=$IP_ADDRESS:8400" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export CONSUL_HTTP_ADDR=$IP_ADDRESS:8500" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export VAULT_ADDR=http://$IP_ADDRESS:8200" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre"  | sudo tee --append /home/$HOME_DIR/.bashrc
