.PHONY: bootstrap deploy update stop restart logs status backup restore harden monitoring-up monitoring-down grafana

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

# Print Grafana access instructions
grafana:
	@echo "Grafana is bound to 127.0.0.1:3001 (not exposed publicly)."
	@echo "Access via SSH tunnel:"
	@echo "  ssh -L 3001:localhost:3001 ubuntu@$$(grep DOMAIN .env | cut -d= -f2)"
	@echo "Then open: http://localhost:3001"
	@echo "Default credentials: admin / (GRAFANA_PASSWORD from .env)"
