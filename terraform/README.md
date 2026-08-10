# Terraform — infrastructure layer

Provisions the host and cloud firewall on Hetzner Cloud, then writes
`../ansible/inventory/hosts.ini` so the Ansible layer knows where to connect.

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in your API token
terraform init
terraform plan
terraform apply
```

## Why Hetzner

The README costs this stack at roughly $40/month. A Hetzner `cx22` in an EU region
runs well under that and keeps the data inside the EU, which is the point of the
GDPR / data-residency argument the project makes.

To target a different provider, replace `hcloud_server` and `hcloud_firewall` in
`main.tf`. The contract with Ansible is only the generated inventory file, so
nothing downstream changes.

## Notes

- `prevent_destroy` is set on the server. It holds the Gitea repositories and the
  Postgres volume. Confirm your backups live off-host before removing it.
- The cloud firewall duplicates the UFW rules applied by Ansible. That is
  intentional — two independent layers — but it means a port opened in one place
  must be opened in the other.
- `admin_cidrs` defaults to the whole internet so a first apply cannot lock you
  out. Narrow it once you have confirmed access.
