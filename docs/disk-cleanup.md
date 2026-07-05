# Your disk WILL fill up — automate cleanup before it does

**Symptom:** months after setup, deploys start failing, Postgres won't write, or the whole server locks up. `df -h /` shows 95-100%.

**Cause:** two silent growers on every Coolify host:

1. **Docker build cache** — every deploy leaves build layers behind. On a busy repo this is gigabytes per week.
2. **Container logs** — default `json-file` driver has **no size limit**. One chatty container can produce a 20GB log file.

An 80GB disk feels infinite on day 1 and is full by month 4. This is the most common "my Coolify site went down" root cause.

## 🚨 Emergency: disk is full RIGHT NOW

```bash
df -h /                          # confirm
docker system df                 # see what Docker is holding
docker builder prune -af         # 1) build cache — usually the biggest win, always safe
docker system prune -af          # 2) unused images/containers/networks (next deploy rebuilds from scratch)
# 3) find oversized container logs:
du -sh /var/lib/docker/containers/*/*-json.log 2>/dev/null | sort -rh | head -5
truncate -s 0 /var/lib/docker/containers/<id>/<id>-json.log   # safe to truncate live
```

Then install the permanent fix below so it never happens again.

## Prerequisites

Root access. Nothing else.

## Check

```bash
df -h /                                          # current usage
docker system df                                 # build cache size
grep -s max-size /etc/docker/daemon.json         # log rotation configured?
ls /etc/cron.d/docker-cleanup 2>/dev/null        # cleanup crons installed?
```

## Apply

Both fixes are in [`server-setup/setup.sh`](../server-setup/setup.sh) (interactive). Manually:

**1. Log rotation** — `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
```

Then `systemctl restart docker` (⚠️ restarts every container — pick a quiet moment). Applies to containers created *after* the restart; redeploy your apps in Coolify.

**2. 3-tier cleanup crons** — `/etc/cron.d/docker-cleanup`:

```cron
# Tier 1: daily hygiene — prune build cache older than 24h
0 3 * * * root docker builder prune -f --filter "until=24h" >> /var/log/docker-cleanup.log 2>&1
# Tier 2: pressure valve — disk >70%, prune unused objects
0 */6 * * * root [ "$(df --output=pcent / | tail -1 | tr -dc '0-9')" -gt 70 ] && docker system prune -f >> /var/log/docker-cleanup.log 2>&1
# Tier 3: keep-alive — disk >85%, prune everything unused incl. images
30 * * * * root [ "$(df --output=pcent / | tail -1 | tr -dc '0-9')" -gt 85 ] && docker system prune -af >> /var/log/docker-cleanup.log 2>&1
```

**Why three tiers instead of one big daily prune:** tier 1 keeps builds fast (recent cache survives). Tier 2 only acts under pressure. Tier 3 trades build speed for uptime — after it fires, the next deploy rebuilds from scratch (slow, not broken). A single aggressive daily prune would make *every* deploy slow; a single gentle one wouldn't save you during a growth spike.

## Verify

```bash
cat /etc/cron.d/docker-cleanup                   # crons present
tail /var/log/docker-cleanup.log                 # after 03:00: tier 1 ran
docker inspect <any-new-container> --format '{{.HostConfig.LogConfig}}'
# Expected: {json-file map[max-file:3 max-size:10m]}
```

## Notes

- Tier 3 deliberately does **not** use `--volumes`: named volumes hold databases. Never auto-prune volumes.
- Coolify has its own "Docker cleanup" setting — it's a good complement, but it didn't exist / wasn't aggressive enough for our growth curve. The crons are provider-independent insurance.
