# One service per Coolify app — never bundle API + web in one container

**The rule:** in a monorepo with an API and a web frontend, create **two Coolify apps** with **two Dockerfiles** (`Dockerfile.api`, `Dockerfile.web`), each with its own domain (e.g. `api.example.com` and `example.com`).

**How we learned it:** we once pointed the web app at a combined Dockerfile (nginx + API in one image). The API half required env vars (`JWT_SECRET`, DB credentials) that only existed in the *API* app's Coolify config. The container crash-looped — and because nginx lived in the same container, **the entire site went down**, not just the API. Full incident: [incidents/2026-06-combined-dockerfile-outage.md](incidents/2026-06-combined-dockerfile-outage.md).

## Why separation wins

| | Combined container | Two apps |
|---|---|---|
| API crash takes down static site | ✅ yes | ❌ no — web is just nginx, nearly uncrashable |
| Env vars | one merged, error-prone set | each app only knows its own |
| Selective deploy | impossible — always both | web-only change never restarts the API |
| Resource blame | tangled | `docker stats` tells you exactly who's eating RAM |

## Prerequisites

- Monorepo with separable services
- Two DNS records (e.g. `example.com`, `api.example.com`) → both to the server; Traefik (Coolify manages it) routes by domain

## Apply

1. Two Dockerfiles at repo root — working examples in [`docker/`](../docker/): [`Dockerfile.api`](../docker/Dockerfile.api), [`Dockerfile.web`](../docker/Dockerfile.web).
2. Two Coolify apps from the same Git repo, each with **Dockerfile Location** set to its own file, its own domain, and its own env vars.
3. CORS: the API must allowlist the web origin. Webhooks and OAuth callbacks always use the **API domain**.

## The Vite build-time env trap (bonus gotcha)

`VITE_*` variables are baked in at **build time**. Setting them as runtime env vars in the Coolify UI does nothing — the bundle was already built without them, and it fails **silently** (`undefined` at runtime). Each one needs:

1. `ARG VITE_API_URL` declared in `Dockerfile.web`'s build stage
2. The value set as a **build variable** in Coolify

## Verify

- `/api` on the web domain is dead → **correct and expected**; the API lives on its own domain.
- Kill the API container manually (`docker stop`) → the site still loads (data fetches fail, but nginx serves). That's the resilience you bought.
- Web-only deploys don't restart the API container (check container uptime in Coolify).
