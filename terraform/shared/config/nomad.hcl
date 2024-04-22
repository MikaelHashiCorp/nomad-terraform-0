# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"
log_level = "TRACE"
log_file  = "/opt/nomad/logs/"
log_rotate_duration  = "3h"
log_rotate_max_files = 3

# Enable the server
server {
  enabled          = true
  bootstrap_expect = SERVER_COUNT
}

consul {
  address = "127.0.0.1:8500"
}

vault {
  enabled          = false
  address          = "http://active.vault.service.consul:8200"
  task_token_ttl   = "1h"
  create_from_role = "nomad-cluster"
  token            = ""
}

