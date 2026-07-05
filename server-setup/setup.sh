#!/usr/bin/env bash
#
# Coolify Production Playbook — server hardening script
# https://github.com/YOUR_GITHUB_USER/coolify-production-playbook
#
# Interactive and idempotent: asks before each module, skips anything already
# configured, and is safe to re-run. Read the whole file before running —
# it's short on purpose.
#
# Modules:
#   1. Swap (2GB)                — prevents OOM kills on small VPSes
#   2. Docker log rotation       — stops container logs from eating the disk
#   3. 3-tier disk cleanup crons — daily prune / >70% aggressive / >85% nuclear
#
# Usage: sudo bash setup.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must run as root (sudo bash setup.sh)." >&2
  exit 1
fi

ask() { # ask "question" -> returns 0 on yes
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

echo "=== Coolify Production Playbook: server setup ==="
echo "Each module asks before changing anything. Already-configured modules are skipped."
echo

# ---------------------------------------------------------------------------
# 1. Swap — small VPSes (2-8GB RAM) hit OOM during builds without it.
# ---------------------------------------------------------------------------
if swapon --show | grep -q '.'; then
  echo "[swap] Already active ($(swapon --show --noheadings | awk '{print $3}' | head -1)) — skipping."
elif ask "[swap] No swap found. Create a 2GB swapfile?"; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  # Prefer RAM; swap is a safety net, not working memory.
  sysctl vm.swappiness=10
  grep -q 'vm.swappiness' /etc/sysctl.conf || echo 'vm.swappiness=10' >> /etc/sysctl.conf
  echo "[swap] 2GB swapfile active and persisted in /etc/fstab."
fi
echo

# ---------------------------------------------------------------------------
# 2. Docker log rotation — without this, a chatty container's json log grows
#    unbounded and fills the disk. This is the #1 silent disk killer.
#    NOTE: applying requires a Docker restart = brief downtime for ALL apps.
# ---------------------------------------------------------------------------
DAEMON_JSON=/etc/docker/daemon.json
if [ -f "$DAEMON_JSON" ] && grep -q 'max-size' "$DAEMON_JSON"; then
  echo "[logs] Log rotation already configured in $DAEMON_JSON — skipping."
elif ask "[logs] Configure Docker log rotation (10MB x 3 files per container)? Requires 'systemctl restart docker' (brief downtime)."; then
  if [ -f "$DAEMON_JSON" ]; then
    cp "$DAEMON_JSON" "$DAEMON_JSON.bak.$(date +%s)"
    echo "[logs] Existing daemon.json backed up. MERGE the log-opts manually:"
    echo '       "log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}'
    echo "[logs] Not overwriting automatically — merge, then: systemctl restart docker"
  else
    cat > "$DAEMON_JSON" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
    echo "[logs] Written. Restart Docker when ready (restarts all containers):"
    echo "       systemctl restart docker"
    echo "[logs] Rotation applies to NEW containers; redeploy apps in Coolify to pick it up."
  fi
fi
echo

# ---------------------------------------------------------------------------
# 3. 3-tier disk cleanup — Docker build cache is the other disk killer.
#    Tier 1 (daily 03:00):   builder prune >24h old        — routine hygiene
#    Tier 2 (every 6h, >70%): system prune + old images    — pressure valve
#    Tier 3 (hourly, >85%):  prune -a --volumes (dangling) — keep site alive
# ---------------------------------------------------------------------------
CRON_FILE=/etc/cron.d/docker-cleanup
if [ -f "$CRON_FILE" ]; then
  echo "[disk] $CRON_FILE already exists — skipping. Review it against docker-cleanup.cron in this repo."
elif ask "[disk] Install 3-tier Docker disk cleanup crons ($CRON_FILE)?"; then
  cat > "$CRON_FILE" <<'EOF'
# Coolify Production Playbook — 3-tier Docker disk cleanup
# Tier 1: daily builder-cache prune (build cache is the biggest silent grower)
0 3 * * * root docker builder prune -f --filter "until=24h" >> /var/log/docker-cleanup.log 2>&1
# Tier 2: if disk >70%, aggressive prune (stopped containers, dangling images, unused networks)
0 */6 * * * root [ "$(df --output=pcent / | tail -1 | tr -dc '0-9')" -gt 70 ] && docker system prune -f >> /var/log/docker-cleanup.log 2>&1
# Tier 3: if disk >85%, nuclear — everything unused incl. all images not in use. Keeps the site alive.
30 * * * * root [ "$(df --output=pcent / | tail -1 | tr -dc '0-9')" -gt 85 ] && docker system prune -af >> /var/log/docker-cleanup.log 2>&1
EOF
  chmod 644 "$CRON_FILE"
  echo "[disk] Installed. Log: /var/log/docker-cleanup.log"
  echo "[disk] NOTE: tier 3 removes unused images — next deploy after it fires rebuilds from scratch (slower, not broken)."
fi
echo

# ---------------------------------------------------------------------------
# Done — print current state so the user (or their AI agent) can verify.
# ---------------------------------------------------------------------------
echo "=== Verification ==="
echo "- Swap:        $(swapon --show --noheadings | awk '{print $1, $3}' | head -1 || echo 'none')"
echo "- Log opts:    $(grep -o 'max-size[^,}]*' $DAEMON_JSON 2>/dev/null || echo 'not configured')"
echo "- Cleanup cron: $([ -f $CRON_FILE ] && echo installed || echo 'not installed')"
echo "- Disk usage:  $(df -h / | tail -1 | awk '{print $5 " of " $2}')"
echo
echo "Next steps (manual, documented in docs/):"
echo "  - PostgreSQL tuning (max_connections, idle_session_timeout): docs/postgres-small-vps.md"
echo "  - CI/CD deploy over SSH: docs/cloudflare-bot-fight.md"
