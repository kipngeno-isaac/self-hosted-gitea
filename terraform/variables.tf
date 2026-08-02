variable "hcloud_token" {
  description = "Hetzner Cloud API token (Project > Security > API tokens, Read & Write)."
  type        = string
  sensitive   = true
}

variable "name" {
  description = "Name prefix for all created resources."
  type        = string
  default     = "gitea"
}

variable "location" {
  description = "Hetzner location. EU options: nbg1 (Nuremberg), fsn1 (Falkenstein), hel1 (Helsinki)."
  type        = string
  default     = "nbg1"
}

variable "server_type" {
  description = <<-EOT
    Hetzner server type. cx22 (2 vCPU / 4 GB) is the practical floor for the full
    nine-container stack: Postgres, Redis, Gitea, three Act Runners, node-exporter,
    Prometheus, Grafana. cx32 gives comfortable headroom for parallel CI.
  EOT
  type        = string
  default     = "cx22"
}

variable "image" {
  description = "Base OS image. The Ansible roles target Ubuntu 22.04 and 24.04."
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_public_key_path" {
  description = "Path to the public key uploaded to the server for admin access."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Path to the matching private key. Written into the generated Ansible inventory."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "admin_cidrs" {
  description = <<-EOT
    Source ranges permitted to reach SSH (22) and Gitea SSH (222) at the cloud
    firewall. Defaults to the whole internet so a first apply cannot lock you out —
    narrow this to your own address before treating the host as production.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "generate_ansible_inventory" {
  description = "Write ansible/inventory/hosts.ini from the created server."
  type        = bool
  default     = true
}
