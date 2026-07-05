# Hetzner for Coolify: picking the server, firewall, backups

Coolify's install guide starts at "run this script on a server". This doc is everything *before and around* that script on Hetzner Cloud — the choices that are annoying to change later.

## Picking the server type

| Line | What it is | When |
|------|-----------|------|
| **CX** (shared Intel/AMD) | Cheapest x86. "Shared" = noisy neighbors can steal CPU during *their* peaks | Hobby projects, staging |
| **CAX** (shared ARM Ampere) | Best price/performance on paper | Only if **every** image you deploy has an arm64 build — check before, not after |
| **CCX** (dedicated vCPU) | Your cores are yours, always | **Production.** Databases hate CPU steal; p95 latency stays flat |

**Our pick: CCX13** (2 dedicated vCPU / 8GB / 80GB NVMe, ~€13/month) running Coolify + API + web + PostgreSQL + background workers for a production SaaS, comfortably.

Sizing rules of thumb:

- **8GB RAM minimum** if PostgreSQL lives on the same box as your apps. 4GB works until your first heavy Docker build OOMs the database (add swap regardless — [setup.sh](../server-setup/setup.sh) does it).
- **Disk fills before CPU runs out.** 80GB is fine *with* the [cleanup crons](disk-cleanup.md); without them, no size is fine.
- Location: pick the DC closest to your users; you can't move a server between locations later (snapshot → new server is the workaround).

## Hetzner Cloud Firewall (free — use it)

Coolify listens on some ports you do **not** want public: `8000` (dashboard HTTP), `6001`/`6002` (realtime/terminal). Traefik serves the dashboard properly over 443 via your Coolify domain — nothing but web traffic and SSH needs to reach the box.

### Check

```bash
# From your LAPTOP (not the server) — these should time out / be refused:
nc -zv -w3 YOUR_SERVER_IP 8000
nc -zv -w3 YOUR_SERVER_IP 5432   # never expose PostgreSQL; use SSH tunnels
```

### Apply

Hetzner Console → Firewalls → Create:

| Direction | Port | Source |
|-----------|------|--------|
| Inbound | 22/tcp | your IP(s) if static, else `0.0.0.0/0` (keys-only SSH) |
| Inbound | 80/tcp | `0.0.0.0/0` (needed for Let's Encrypt HTTP challenge + redirect) |
| Inbound | 443/tcp | `0.0.0.0/0` |
| Inbound | *(nothing else)* | |

Apply the firewall to the server. Outbound: leave unrestricted.

This is enforced **outside** the box — a misconfigured container publishing a port can't accidentally expose itself, and it costs nothing.

### Verify

Re-run the `nc` checks above (should fail); `curl -I https://your-coolify-domain` still works; you can still SSH in.

### DB access without exposing 5432

```bash
ssh -N -L 15432:localhost:5432 root@YOUR_SERVER_IP
# then connect any client to localhost:15432
```

## Backups: two layers, both non-negotiable

1. **Hetzner automated backups** (server → Backups → enable, +20% of server price ≈ €2.6 on a CCX13): 7 rolling full-server images. This is your "the whole box died / I broke the OS" recovery. Snapshots are the manual cousin — take one before risky server surgery.
2. **Database-level backups** — a server image is not a database backup (restore granularity: the whole machine, up to 24h old). Use Coolify's scheduled database backups to S3-compatible storage (Cloudflare R2's free tier works). **Test one restore.** An untested backup is a hope, not a backup.

## Small stuff that bites later

- **Keep the assigned IPv4.** Changing servers? Use a Floating IP or update DNS carefully — with Cloudflare proxied DNS in front, IP changes are invisible to users (orange cloud = only Cloudflare knows your IP; a nice side-benefit: nobody can DDoS the origin directly if you also firewall non-Cloudflare HTTP sources).
- **Cloudflare SSL mode: "Full (strict)"** — Traefik/Let's Encrypt gives you a real origin cert, so strict works. "Flexible" causes redirect loops with Coolify's HTTPS redirect; don't.
- **Hetzner's console graphs** (CPU/disk/network) are free monitoring — check the disk graph monthly until the cleanup crons have proven themselves on your workload.
