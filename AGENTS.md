# Instructions for AI agents

You (an AI coding agent) have been pointed at this repo to help a user run Coolify in production — typically to harden a fresh server, set up CI/CD, or debug a deploy/disk/database problem.

## Ground rules

1. **Adapt, don't replay.** Every doc follows *Prerequisites → Check → Apply → Verify*. Always run the **Check** commands first and skip steps that are already satisfied (existing swap, existing cron, already-tuned Postgres). The user's server is not our server.
2. **Never apply anything to production without showing the user what will change.** Summarize the planned changes (files written, services restarted) before executing.
3. **Everything here is idempotent by design** — `setup.sh` can be re-run safely. If you modify it for the user's environment, preserve that property.
4. **Do not restart Docker or PostgreSQL during business hours** without explicit user confirmation. `daemon.json` changes require a Docker restart, which restarts every container on the host (= downtime).
5. **Secrets discipline:** never echo, log, or commit `COOLIFY_TOKEN`, SSH private keys, or database URLs. When editing `deploy.yml`, reference GitHub Secrets — never inline values.
6. **Verify before declaring success.** Every doc has a **Verify** section with concrete commands and expected output. Run them. "It should work now" is not done.

## Task → entry point map

| User asks for | Start at |
|---------------|----------|
| "Harden / prepare my server" | `server-setup/setup.sh` (read it, then run module by module) |
| "Set up CI/CD / auto-deploy" | `.github/workflows/deploy.yml` + `docs/cloudflare-bot-fight.md` |
| "Deploys stopped working / webhook fails" | `docs/cloudflare-bot-fight.md` |
| "Disk full / site down / no space" | `docs/disk-cleanup.md` (emergency section first) |
| "Only deploy what changed in my monorepo" | `docs/selective-monorepo-deploy.md` |
| "Migrations broke production" | `docs/migration-smoke-test.md` |
| "How should I structure Dockerfiles" | `docs/two-apps-two-dockerfiles.md` + `docker/` |
| "Postgres connection errors / slowness" | `docs/postgres-small-vps.md` |

## Environment assumptions (verify, don't assume)

The docs assume: Ubuntu/Debian host, Coolify installed at `http://localhost:8000` on the server, Docker + Traefik managed by Coolify, GitHub Actions as CI. Check with:

```bash
lsb_release -a                      # distro
docker --version && docker ps       # docker running, coolify containers visible
curl -sf http://localhost:8000/api/health || echo "coolify API not on :8000"
```

If the user's environment differs (different distro, different CI, Coolify behind a different port), adapt the commands and tell the user what you changed.

## When something isn't covered here

Say so explicitly. Do not present guesses as playbook content. The user can open an issue at this repo — real-world gaps are how it grows.
