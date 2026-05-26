# Security

## Reporting a Vulnerability

Open a private issue or email the maintainer directly. Do not disclose vulnerabilities publicly before they are resolved.

---

## Defence-in-Depth Overview

```
Internet
   │
   ▼
UFW (firewall) — allows only 22, 80, 443, 222
   │
   ▼
Nginx (TLS termination) — TLS 1.2/1.3, HSTS, security headers
   │
   ▼
Gitea (port 3000, bound to 127.0.0.1 only)
   │
   ├── PostgreSQL (Docker-internal only, never exposed to host)
   ├── Redis      (Docker-internal only, never exposed to host)
   └── Act Runners (Docker-internal only)
```

---

## Hardening Controls

| Control | Implementation |
|---|---|
| Firewall | UFW — deny all inbound except ports 22, 80, 443, 222 |
| Brute-force protection | fail2ban jails for SSH, Nginx, and Gitea login |
| TLS | Let's Encrypt certificate, TLS 1.2/1.3 only, HSTS enabled |
| Security headers | X-Frame-Options, X-Content-Type-Options, X-XSS-Protection |
| SSH | Key-only authentication, root login disabled, MaxAuthTries 3 |
| Container isolation | Gitea port bound to 127.0.0.1; database and Redis not exposed |
| Registration | Disabled by default — users created via admin CLI only |
| Auto-updates | unattended-upgrades applies security patches automatically |
| Sysctl | SYN flood protection, source routing disabled, martian packet logging |

Run all hardening controls in one step:

```bash
make harden
# or: sudo bash scripts/harden.sh
```

---

## Secrets Management

| Secret | Location |
|---|---|
| All credentials | `.env` file — git-ignored, never committed |
| TLS private key | `/etc/letsencrypt/live/<domain>/privkey.pem` — readable by root only |
| Gitea internal token | Auto-generated on first boot, stored in `app.ini` inside the data volume |
| LFS JWT secret | Auto-generated on first boot |

**For production / team environments**, replace the `.env` file with a secrets manager:
- HashiCorp Vault
- AWS Secrets Manager / Parameter Store
- Gitea's built-in secret store (for CI/CD secrets)

---

## Monitoring & Alerting

Prometheus scrapes Gitea and system metrics. Grafana dashboards surface anomalies. Recommended Grafana alerts to configure:

- CPU > 80% sustained for 5 min
- Available disk < 20 GB
- Gitea container down
- fail2ban ban rate spike (indicates active brute-force)

---

## Backup & Recovery

Backups include the Git data volume and a PostgreSQL dump. Restore is fully scripted — see [README.md](README.md#restore-from-backup).

Recommended: ship backups offsite (S3, B2, rsync to separate host) and test restores periodically.

---

## Known Limitations

- **Act Runners share the host Docker socket** — a malicious CI job could escape the container. Mitigate by using Gitea's job allow-listing and restricting which repos can trigger workflows.
- **No WAF** — Nginx does not include a web application firewall. ModSecurity or Cloudflare can be added in front.
- **Single-node** — no HA or failover. A host failure means downtime until the backup is restored.
