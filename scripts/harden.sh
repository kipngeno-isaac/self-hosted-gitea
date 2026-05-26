#!/usr/bin/env bash
# Hardens the host OS: UFW firewall, fail2ban, SSH config, unattended-upgrades.
# Usage: sudo bash scripts/harden.sh
# Safe to re-run — all operations are idempotent.

set -euo pipefail

[[ $EUID -ne 0 ]] && { echo "ERROR: Run as root (sudo)"; exit 1; }

echo "==> Installing hardening packages"
apt-get update -y
apt-get install -y ufw fail2ban unattended-upgrades apt-listchanges

# ── UFW Firewall ─────────────────────────────────────────────────────────────
echo "==> Configuring UFW"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   comment "SSH"
ufw allow 80/tcp   comment "HTTP (Nginx → HTTPS redirect)"
ufw allow 443/tcp  comment "HTTPS"
ufw allow 222/tcp  comment "Gitea SSH"
ufw --force enable
ufw status verbose

# ── SSH Hardening ─────────────────────────────────────────────────────────────
echo "==> Hardening SSH"
SSHD=/etc/ssh/sshd_config
cp -n "$SSHD" "${SSHD}.bak"

# Disable password authentication, enable key-only login
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD"
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD"
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "$SSHD"

# Add settings if not already present
grep -q "^MaxAuthTries" "$SSHD" || echo "MaxAuthTries 3" >> "$SSHD"
grep -q "^ClientAliveInterval" "$SSHD" || echo "ClientAliveInterval 300" >> "$SSHD"
grep -q "^ClientAliveCountMax" "$SSHD" || echo "ClientAliveCountMax 2" >> "$SSHD"

sshd -t && systemctl reload ssh
echo "==> SSH hardened"

# ── fail2ban ─────────────────────────────────────────────────────────────────
echo "==> Configuring fail2ban"
cat > /etc/fail2ban/jail.d/gitea.conf <<'EOF'
[sshd]
enabled  = true
port     = ssh
maxretry = 5
bantime  = 1h
findtime = 10m

[nginx-http-auth]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 5
bantime  = 1h

[gitea]
enabled  = true
port     = http,https
filter   = gitea
logpath  = /home/ubuntu/gitea/gitea-data/gitea/log/gitea.log
maxretry = 10
bantime  = 1h
findtime = 10m
EOF

cat > /etc/fail2ban/filter.d/gitea.conf <<'EOF'
[Definition]
failregex = .* Failed authentication attempt for .* from <HOST>
            .* invalid credentials from <HOST>
ignoreregex =
EOF

systemctl enable --now fail2ban
systemctl restart fail2ban
echo "==> fail2ban configured"

# ── Unattended Upgrades ───────────────────────────────────────────────────────
echo "==> Enabling unattended security upgrades"
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

systemctl enable --now unattended-upgrades
echo "==> Unattended upgrades enabled"

# ── Kernel / sysctl Hardening ─────────────────────────────────────────────────
echo "==> Applying sysctl hardening"
cat > /etc/sysctl.d/99-harden.conf <<'EOF'
# Disable IP forwarding (we're not a router)
net.ipv4.ip_forward = 0
# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1
# Ignore bogus ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1
# SYN flood protection
net.ipv4.tcp_syncookies = 1
# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
# Log martian packets
net.ipv4.conf.all.log_martians = 1
EOF
sysctl --system

echo ""
echo "==> Hardening complete."
echo "    Firewall rules:"
ufw status numbered
echo ""
echo "    fail2ban status:"
fail2ban-client status
