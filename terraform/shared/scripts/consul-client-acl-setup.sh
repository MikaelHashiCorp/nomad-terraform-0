#!/bin/bash

# SSH_AUTH variable
SSH_AUTH="${HOME}/.ssh/support_nomad_dev-access-key-mikael.pem"

# Get the default token from consul-tokens.hcl
DEFAULT_TOKEN=$(grep 'default' /etc/consul.d/consul-tokens.hcl | awk -F'=' '{print $2}' | tr -d ' "')

# Get the IP addresses of all client nodes
client_ips=$(consul members | awk '/client/ {print $2}' | cut -d: -f1)

# Loop over each client IP
for ip in $client_ips; do
  # Copy the file to a temporary location on the client node
  scp -i $SSH_AUTH /etc/consul.d/consul-acl.hcl "ubuntu@${ip}:/tmp/consul-acl.hcl"
  
  # Move the file to the final location
  ssh -i $SSH_AUTH ubuntu@${ip} "sudo mv /tmp/consul-acl.hcl /etc/consul.d/consul-acl.hcl"
  
  # Append the export line to .bashrc on the client node
  ssh -i $SSH_AUTH ubuntu@${ip} "echo 'export CONSUL_HTTP_TOKEN=$DEFAULT_TOKEN' | sudo tee -a /home/ubuntu/.bashrc"

  # Restart Consul on the client node
  ssh -i $SSH_AUTH ubuntu@$ip "sudo systemctl restart consul"
done
