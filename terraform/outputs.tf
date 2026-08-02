output "server_ipv4" {
  description = "Public IPv4 address. Point your DOMAIN A record here before running Ansible."
  value       = hcloud_server.gitea.ipv4_address
}

output "server_ipv6" {
  description = "Public IPv6 address."
  value       = hcloud_server.gitea.ipv6_address
}

output "ssh_command" {
  description = "Convenience SSH command for the new host."
  value       = "ssh -i ${var.ssh_private_key_path} root@${hcloud_server.gitea.ipv4_address}"
}

output "next_steps" {
  description = "What to do after apply."
  value       = <<-EOT
    1. Point the DNS A record for your DOMAIN at ${hcloud_server.gitea.ipv4_address}
       and wait for it to resolve — Let's Encrypt will fail otherwise.
    2. Copy .env.example to .env at the repository root and fill in the values.
    3. Run: make ansible-deploy
  EOT
}
