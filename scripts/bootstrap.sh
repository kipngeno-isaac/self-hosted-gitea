#!/usr/bin/env bash
# Run once on a fresh Ubuntu 22.04/24.04 server to install all dependencies.
# Usage: sudo bash scripts/bootstrap.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Load .env ────────────────────────────────────────────────────────────────
if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill in values."
  exit 1
fi
set -a; source "$ROOT_DIR/.env"; set +a

# ── Packages ─────────────────────────────────────────────────────────────────
echo "==> Updating system packages"
apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg lsb-release nginx certbot python3-certbot-nginx gettext-base

# ── Docker ───────────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "==> Installing Docker"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
else
  echo "==> Docker already installed — skipping"
fi

# Add deploy user to docker group if not root
if [[ "${SUDO_USER:-}" != "" ]]; then
  usermod -aG docker "$SUDO_USER"
  echo "==> Added $SUDO_USER to docker group (re-login to apply)"
fi

# ── Nginx ────────────────────────────────────────────────────────────────────
echo "==> Configuring Nginx"
envsubst '${DOMAIN}' < "$ROOT_DIR/nginx/gitea.conf.template" \
  > /etc/nginx/sites-available/gitea
ln -sf /etc/nginx/sites-available/gitea /etc/nginx/sites-enabled/gitea
rm -f /etc/nginx/sites-enabled/default

# Temporary HTTP-only config for certbot (no TLS block yet)
cat > /etc/nginx/sites-available/gitea-http-only <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    location / { return 200 'ok'; add_header Content-Type text/plain; }
}
EOF
ln -sf /etc/nginx/sites-available/gitea-http-only /etc/nginx/sites-enabled/gitea
nginx -t && systemctl reload nginx

# ── TLS Certificate ──────────────────────────────────────────────────────────
if [[ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
  echo "==> Obtaining Let's Encrypt certificate for ${DOMAIN}"
  certbot certonly --nginx \
    -d "${DOMAIN}" \
    --non-interactive \
    --agree-tos \
    --email "${LETSENCRYPT_EMAIL}"
else
  echo "==> Certificate already exists — skipping certbot"
fi

# Switch to full TLS Nginx config
envsubst '${DOMAIN}' < "$ROOT_DIR/nginx/gitea.conf.template" \
  > /etc/nginx/sites-available/gitea
ln -sf /etc/nginx/sites-available/gitea /etc/nginx/sites-enabled/gitea
rm -f /etc/nginx/sites-available/gitea-http-only
nginx -t && systemctl reload nginx

# ── Certbot auto-renewal ─────────────────────────────────────────────────────
systemctl enable --now certbot.timer 2>/dev/null || true

echo ""
echo "==> Bootstrap complete. Run 'make deploy' (or scripts/deploy.sh) to start Gitea."
