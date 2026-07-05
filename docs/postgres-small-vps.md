# PostgreSQL on a small VPS: the three settings that matter

**Symptom:** intermittent `remaining connection slots are reserved` / `too many clients already` errors, or the whole box grinding under memory pressure during deploys.

**Cause:** on a 2-vCPU / 8GB VPS running Coolify + your apps + PostgreSQL, the defaults assume a dedicated DB server. Three cheap changes prevent the common failures.

## Prerequisites

PostgreSQL running as a Docker container (Coolify-managed or your own). Find it: `docker ps | grep postgres`.

## Check

```bash
docker exec -it <postgres-container> psql -U postgres -c "SHOW max_connections; SHOW idle_session_timeout;"
docker exec -it <postgres-container> psql -U postgres -c \
  "SELECT state, count(*) FROM pg_stat_activity GROUP BY state;"
swapon --show    # any swap at all?
```

Red flags: `max_connections=100` with multiple app pools, `idle_session_timeout=0` (never), a pile of `idle` sessions, no swap.

## Apply

**1. `max_connections=200`** — headroom for app pool + background-worker pool + admin tools + deploy overlap (during a rolling deploy, old and new containers hold pools *simultaneously* — this doubles your connection count for a minute, and is exactly when the default runs out):

```bash
docker exec -it <postgres-container> psql -U postgres -c "ALTER SYSTEM SET max_connections = 200;"
docker restart <postgres-container>   # requires restart — pick a quiet moment
```

**2. `idle_session_timeout=15min`** — leaked/forgotten sessions (a psql you left open, a crashed worker's pool) get reaped instead of holding slots forever:

```bash
docker exec -it <postgres-container> psql -U postgres -c "ALTER SYSTEM SET idle_session_timeout = '15min';"
docker exec -it <postgres-container> psql -U postgres -c "SELECT pg_reload_conf();"   # no restart needed
```

⚠️ If your app expects long-lived idle pool connections without keepalives, make the pool's `idleTimeoutMillis` *shorter* than 15min so the pool recycles before Postgres kills.

**3. 2GB swap** — not for Postgres to *use*, but so a build-time memory spike triggers swapping instead of the kernel OOM-killing your database. `server-setup/setup.sh` does this, or see any swapfile guide.

## App-side rule that pairs with this

Use **two pools**: a main pool for request handling and a separate small pool for background jobs/crons. A slow cron batch otherwise starves user requests of connections. (In `node-postgres`: two `Pool` instances with their own `max`.)

## Verify

```bash
docker exec -it <postgres-container> psql -U postgres -c "SHOW max_connections;"        # 200
docker exec -it <postgres-container> psql -U postgres -c "SHOW idle_session_timeout;"  # 15min
swapon --show                                                                          # /swapfile 2G
```

## Notes

- Memory tuning (`shared_buffers` etc.): on 8GB shared with apps, the defaults are conservative-but-fine. Don't cargo-cult "25% of RAM" — that assumes a dedicated DB box.
- Backups are out of scope here but non-negotiable: Coolify has scheduled DB backups to S3-compatible storage — turn them on and **test a restore once**.
