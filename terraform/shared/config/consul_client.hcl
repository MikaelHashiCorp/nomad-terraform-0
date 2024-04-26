# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

ui_config {
  enabled = true
}
log_level      = "TRACE"
data_dir       = "/opt/consul/data"
bind_addr      = "0.0.0.0"
client_addr    = "0.0.0.0"
advertise_addr = "IP_ADDRESS"
retry_join     = ["RETRY_JOIN"]
log_level      = "TRACE"
log_file       = "/opt/consul/logs/"
log_rotate_duration  = "1h"
log_rotate_max_files = 3
ports = {
  grpc = 8502
}
