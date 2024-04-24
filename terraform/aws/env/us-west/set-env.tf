resource "local_file" "env_script" {
  content = <<-EOF
    #!/bin/bash
    # Environment variable setup for HashiStack
    export CONSUL_HTTP_ADDR=http://${module.hashistack.server_lb_ip}:8600
    export NOMAD_ADDR=http://${module.hashistack.server_lb_ip}:4646
    export VAULT_ADDR=http://${module.hashistack.server_lb_ip}:8200
  EOF
  filename = "${path.module}/set_env.sh"
  file_permission = "0755"

  depends_on = [module.hashistack]
}
