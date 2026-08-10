.PHONY: bootstrap deploy update stop restart logs status backup restore harden monitoring-up monitoring-down grafana \
        tf-init tf-plan tf-apply tf-destroy ansible-deps ansible-check ansible-deploy ansible-harden provision

# First-time server setup (run as root/sudo)
bootstrap:
	sudo bash scripts/bootstrap.sh

# Start or update the stack
deploy:
	bash scripts/deploy.sh

# Pull new images and restart
update:
	docker compose pull && docker compose up -d --remove-orphans

# Stop all containers
stop:
	docker compose down

# Restart all containers
restart:
	docker compose restart

# Tail logs for all services (Ctrl+C to exit)
logs:
	docker compose logs -f

# Tail logs for a specific service: make logs-gitea
logs-%:
	docker compose logs -f $*

# Show container status and resource usage
status:
	docker compose ps
	docker stats --no-stream

# Create a backup (saved to ./backups/)
backup:
	bash scripts/backup.sh

# Restore from backup: make restore DATA=backups/gitea-20260101.tar.gz DB=backups/gitea-db-20260101.sql.gz
restore:
	bash scripts/restore.sh $(DATA) $(DB)

# Open a shell in the Gitea container
shell:
	docker exec -it gitea sh

# Run Gitea admin CLI: make admin CMD="user list"
admin:
	docker exec -it gitea gitea admin $(CMD)

# Open psql in the database container
psql:
	docker exec -it gitea-db psql -U $$(grep POSTGRES_USER .env | cut -d= -f2) gitea

# Harden the host OS (UFW, fail2ban, SSH, sysctl)
harden:
	sudo bash scripts/harden.sh

# Start monitoring stack only
monitoring-up:
	docker compose up -d node-exporter prometheus grafana

# Stop monitoring stack
monitoring-down:
	docker compose stop node-exporter prometheus grafana

# Set up public Grafana access (requires grafana.DOMAIN DNS A record to exist)
grafana-public:
	DOMAIN=$$(grep ^DOMAIN .env | cut -d= -f2) && \
	EMAIL=$$(grep ^LETSENCRYPT_EMAIL .env | cut -d= -f2) && \
	envsubst '$$DOMAIN' < nginx/grafana.conf.template > /etc/nginx/sites-available/grafana && \
	ln -sf /etc/nginx/sites-available/grafana /etc/nginx/sites-enabled/grafana && \
	nginx -t && systemctl reload nginx && \
	certbot certonly --nginx -d grafana.$$DOMAIN --non-interactive --agree-tos --email $$EMAIL && \
	nginx -t && systemctl reload nginx
	@echo "Grafana is now live at https://grafana.$$(grep ^DOMAIN .env | cut -d= -f2)"

# Print Grafana access instructions
grafana:
	@echo "Grafana: https://grafana.$$(grep ^DOMAIN .env | cut -d= -f2)"
	@echo "Credentials: admin / (GRAFANA_PASSWORD from .env)"


# ── Infrastructure as Code ───────────────────────────────────────────────────
# Terraform provisions the host; Ansible configures it. The shell scripts above
# still work for a host you provisioned by hand.

# Download providers
tf-init:
	cd terraform && terraform init

# Preview infrastructure changes
tf-plan:
	cd terraform && terraform plan

# Create/update the server and generate the Ansible inventory
tf-apply:
	cd terraform && terraform apply

# Tear down (server has prevent_destroy — remove it first, and check backups)
tf-destroy:
	cd terraform && terraform destroy

# Install required Ansible collections
ansible-deps:
	cd ansible && ansible-galaxy collection install -r requirements.yml

# Dry-run the whole playbook
ansible-check:
	cd ansible && ansible-playbook site.yml --check --diff

# Configure the host and bring the stack up
ansible-deploy:
	cd ansible && ansible-playbook site.yml

# Re-apply security configuration only
ansible-harden:
	cd ansible && ansible-playbook site.yml --tags hardening

# Full path: bare cloud account to running Gitea
provision: tf-init tf-apply ansible-deps ansible-deploy
