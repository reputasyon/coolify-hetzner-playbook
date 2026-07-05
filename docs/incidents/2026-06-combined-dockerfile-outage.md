# One Dockerfile, zero websites (June 2026)

**Impact:** full production outage — the customer-facing site completely down, crash-looping until the configuration was reverted.

## What happened

Our monorepo had three Dockerfiles: `Dockerfile.api` (API only), `Dockerfile.web` (nginx serving the static frontend), and a legacy combined `Dockerfile` (nginx + API in one image, from an earlier single-app era).

During a configuration cleanup, the **web** Coolify app's "Dockerfile Location" was pointed at the combined `Dockerfile` — it looked like the more "complete" option. But the combined image's API half needs runtime secrets (`JWT_SECRET`, database URL, encryption keys) that only exist in the *API* app's Coolify environment. The web app's environment had none of them, by design.

The container started, the API process inside it crashed on missing env vars, the container exited, Coolify restarted it — crash-loop. And since nginx lived in the **same container**, the static site died with it. A misconfiguration that should have cost us nothing took down everything.

## Timeline

- **T+0:** web app redeployed with the combined Dockerfile. Build succeeds (build needs no secrets — the trap).
- **T+1min:** container crash-loops on startup. Site returns 502.
- **T+~15min:** deployment logs show the API process's missing-env-var stack trace *inside the web app's container* — the "why is the API booting here at all?" moment.
- **T+20min:** Dockerfile Location reverted to `Dockerfile.web`, redeploy, site back.

## Root cause

A container bundling two services with different environment contracts, deployable under an app that satisfies only one of them. The build succeeding while the runtime couldn't possibly work made it a delayed-fuse failure.

## Why it wasn't caught

Builds don't validate runtime env requirements. Nothing in Coolify (or any platform) knows that *this* Dockerfile needs *that* env set. Only the pairing convention protects you — and conventions that live in one person's head get cleaned up by the next person.

## What changed

1. **The combined Dockerfile was deleted.** An artifact that is only ever correct in a context that no longer exists is a loaded footgun, not "flexibility".
2. **One service per app, hard rule**, documented with the full rationale: [two-apps-two-dockerfiles.md](../two-apps-two-dockerfiles.md).
3. The pairing (app ↔ Dockerfile ↔ env contract) written down in the repo's own docs, so "cleanup" can't rediscover the footgun.

## The takeaways

- Blast radius is a design decision. Static file serving is nearly unbreakable — unless you chain it to something breakable.
- Delete legacy deploy artifacts instead of keeping them "just in case". The case will come, and it will be someone selecting them from a dropdown.
