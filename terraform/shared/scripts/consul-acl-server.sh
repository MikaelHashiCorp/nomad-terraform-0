#!/bin/bash

echo "Starting consul-acl.hcl file creation..."
# Create or overwrite the file /etc/consul.d/consul-acl.hcl
echo 'acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
}' | sudo tee /etc/consul.d/consul-acl.hcl > /dev/null
echo "File creation complete."

# Restart Consul
echo "Restart Consul"
sudo systemctl restart consul
# Wait for consul to restart
counter=0
while true; do
    if systemctl is-active --quiet consul; then
        echo "Consul has successfully restarted."
        break
    fi
    if (( counter % 5 == 0 )); then
        echo "Waiting for restart to complete..."
    fi
    sleep 1
    ((counter++))
done
sudo systemctl status consul | cat

echo "Bootstrapping Consul..."
# Retry bootstrap command until successful or maximum retries reached
max_retries=5
for ((i=1;i<=max_retries;i++)); do
  bootstrap_response=$(consul acl bootstrap -format=json)
  if [[ $? -eq 0 ]]; then
    echo "$bootstrap_response" | tee consul_bootstrap_response.txt
    bootstrap_secret=$(echo $bootstrap_response | jq -r '.SecretID')
    echo $bootstrap_secret | tee bootstrap_token.txt
    echo "ACL system bootstrap complete."
    # Set the bootstrap secret as an environment variable
    export CONSUL_HTTP_TOKEN=$bootstrap_secret
    break
  else
    echo "Bootstrap attempt $i failed. Retrying..."
    sleep 5
  fi
done

echo "Starting policy creation..."
# Define policy
policy='{
    "Name": "agent-policy",
    "Description": "Agent Token Policy",
    "Rules": "acl = \"write\""
}'

# Create policy
policy_response=$(consul acl policy create -name "agent-policy" -description "Agent Token Policy" -rules 'acl = "write"' -token=$bootstrap_secret -format=json)
echo $policy_response | tee consul_agent_policy.txt
echo "Policy creation complete."

echo "Starting token creation..."
# Define the token
token='{
    "Description": "Agent Token",
    "Policies": [
        {"Name": "agent-policy"}
    ]
}'

# Create the token
token_response=$(consul acl token create -description "Agent Token" -policy-name "agent-policy" -token=$bootstrap_secret -format=json)
echo $token_response | tee consul_agent_token_response.txt
agent_token_secret=$(echo $token_response | jq -r '.SecretID')
echo $agent_token_secret | tee agent_token.txt
echo "Token creation complete."

# Set the token (not needed on server?)
# echo "Set the token"
# consul acl set-agent-token -token=$bootstrap_secret agent $agent_token_secret

echo "Starting file creation..."
# Create or overwrite the file /etc/consul.d/consul-tokens.hcl
echo "acl {
  tokens {
    agent        = \"$agent_token_secret\"
    default      = \"$bootstrap_secret\"
  }
}" | sudo tee /etc/consul.d/consul-tokens.hcl > /dev/null
echo "File creation complete."

echo "Starting Consul restart..."
# Restart consul
sudo systemctl restart consul
# Wait for consul to restart
counter=0
while true; do
    if systemctl is-active --quiet consul; then
        echo "Consul has successfully restarted."
        break
    fi
    if (( counter % 5 == 0 )); then
        echo "Waiting for restart to complete..."
    fi
    sleep 1
    ((counter++))
done
sudo systemctl status consul | cat

# Update the policy
echo "Starting policy update..."
# Create or overwrite the file /home/ubuntu/consul-client-policy.hcl
echo 'acl = "write"

agent_prefix "" {
  policy = "write"
}

event_prefix "" {
  policy = "write"
}

key_prefix "" {
  policy = "write"
}

node_prefix "" {
  policy = "write"
}

query_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "write"
}' | sudo tee /home/ubuntu/consul-client-policy.hcl > /dev/null
echo "File creation complete."

# Update the policy
consul acl policy update -name "agent-policy" -rules @/home/ubuntu/consul-client-policy.hcl -token=$bootstrap_secret
echo "consul agent policy list: ** $(consul acl policy list -token=$bootstrap_secret) **"
echo "Policy update complete."

echo "Starting second Consul restart..."
# Restart consul again
sudo systemctl restart consul

# Wait for consul to restart
end=$((SECONDS+300))
while [ $SECONDS -lt $end ]; do
    if journalctl -u consul | grep -q "agent.client: adding server"; then
        echo "Consul has successfully restarted."
        break
    fi
    echo "Waiting for restart to complete..."
    sleep 15
done
sudo systemctl status consul | cat
echo "*** Finished Bootstrap ***"
