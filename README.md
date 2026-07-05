# Coolify Production Playbook

**Installing Coolify takes 10 minutes. Running it in production for a year is the hard part.**

This repo is everything we learned running a real, revenue-generating SaaS (an e-commerce warehouse-management platform processing live marketplace orders) on a **€13/month Hetzner VPS** with [Coolify](https://coolify.io) — including the incidents, the fixes, and the copy-paste files so you never hit the same walls.

> 🇹🇷 Türkçe sürüm için: [README.tr.md](README.tr.md)

## 🤖 Using an AI assistant? Start here

This playbook is designed to be executed by AI coding agents (Claude Code, Cursor, Codex, ...). Point your assistant at this repo and say:

> *"Read this repo and harden my Coolify server / set up my CI/CD accordingly."*

Every guide follows a machine-friendly structure — **Prerequisites → Check → Apply → Verify** — so an agent can adapt each step to your exact server instead of blindly running commands. Agent-specific instructions live in [AGENTS.md](AGENTS.md).

We deliberately did **not** ship a CLI. You already have one: your assistant. Readable bash + documented YAML beats a black-box binary — for humans and for LLMs.

## What's inside

| Path | What it is |
|------|------------|
| [`server-setup/setup.sh`](server-setup/setup.sh) | Interactive, idempotent hardening script: swap, Docker log rotation, 3-tier disk cleanup crons |
| [`templates/deploy.yml`](templates/deploy.yml) | Battle-tested CI/CD: test → selective monorepo deploy → Coolify API over SSH |
| [`docker/`](docker/) | Split Dockerfiles for a Node monorepo (API + static web) with the "why two apps" rationale |
| [`docs/`](docs/) | Deep dives: every problem we hit, why it happens, how to fix it permanently |
| [`docs/incidents/`](docs/incidents/) | Real production incidents, anonymized — what broke, what it cost, what we changed |

## The problems this repo solves

Each of these cost us hours (sometimes days). Each has a doc with a permanent fix:

1. **[Cloudflare blocks your GitHub deploy webhooks](docs/cloudflare-bot-fight.md)** — Bot Fight Mode silently blocks GitHub's IPs. Fix: trigger Coolify's API over SSH from Actions. The #1 recurring question in Coolify communities.
2. **[Your disk fills up and the site goes down](docs/disk-cleanup.md)** — Docker build cache + logs eat an 80GB disk in months. Fix: 3-tier automated cleanup (daily prune / >70% aggressive / >85% nuclear) + `daemon.json` log rotation.
3. **[Every push redeploys everything in your monorepo](docs/selective-monorepo-deploy.md)** — Fix: path-filtered deploys using the full push range (`github.event.before`, not `HEAD~1` — most examples get this wrong).
4. **[A broken migration boot-loops production](docs/migration-smoke-test.md)** — Fix: run the full migration chain against a fresh PostgreSQL in CI. Broken SQL fails the build, not your API.
5. **[One Dockerfile for API+web takes the whole site down](docs/two-apps-two-dockerfiles.md)** — Fix: two Coolify apps, two Dockerfiles, separate domains. We learned this via a full outage.
6. **[PostgreSQL misbehaves on a small VPS](docs/postgres-small-vps.md)** — connection exhaustion, idle sessions, no swap. Fix: `max_connections`, `idle_session_timeout`, 2GB swap.

## Quick start

### 1. Harden the server (after installing Coolify)

```bash
curl -fsSL https://raw.githubusercontent.com/reputasyon/coolify-production-playbook/main/server-setup/setup.sh -o setup.sh
less setup.sh   # always read scripts before running them — this one is short and commented
sudo bash setup.sh
```

The script is **interactive** (asks before each module) and **idempotent** (safe to re-run; skips what's already configured).

### 2. Set up CI/CD

1. Copy [`templates/deploy.yml`](templates/deploy.yml) into your repo as `.github/workflows/deploy.yml`. (It lives in `templates/` here so it doesn't execute in *this* repo.)
2. Follow the `# CHANGE ME` comments (path filters, workspace names).
3. Add the four secrets:

| Secret | What it is |
|--------|------------|
| `SSH_HOST` | Your server's IP |
| `SSH_PRIVATE_KEY` | A deploy-only SSH key (`ssh-keygen -t ed25519`) |
| `COOLIFY_TOKEN` | Coolify → Keys & Tokens → API tokens |
| `COOLIFY_APP_UUID` | From the app's URL in the Coolify dashboard (one secret per app) |

### 3. Read the incident reports

Seriously — [docs/incidents/](docs/incidents/) is the highest-value part of this repo. Every rule here exists because something broke.

## The stack this is proven on

- **Hetzner CCX13** (2 vCPU / 8 GB / 80 GB) — ~€13/month
- **Coolify** (self-hosted) + Traefik
- **Cloudflare** (free tier, proxied DNS, Bot Fight Mode on)
- **Node.js monorepo** (npm workspaces): Hono API + React/Vite web, PostgreSQL
- **GitHub Actions** for CI/CD

Nothing here is Hetzner-specific — any VPS provider works. The Node monorepo parts generalize to any stack; the server-setup and deploy patterns are stack-agnostic.

## Contributing

Found a Coolify production gotcha we haven't? Open an issue or PR — especially incident write-ups. Requirements: it must be reproducible, and the fix must be tested on a real server.

## License

[MIT](LICENSE)
