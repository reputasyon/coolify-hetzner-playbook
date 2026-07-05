# Selective monorepo deploys (and the `HEAD~1` trap)

**Symptom:** every push to your monorepo redeploys every service. A README change rebuilds your API. Deploys take twice as long and restart services for no reason.

**Fix:** detect which workspace actually changed in the push, and only trigger those Coolify apps.

## The trap almost every example gets wrong

The naive approach diffs the last commit:

```bash
git diff --name-only HEAD~1 HEAD -- api/     # ❌ WRONG
```

A push is not a commit. Push 3 commits at once — API change, web change, docs change — and `HEAD~1` only sees the last one. The API change deploys never happens, **silently**. You now have tested-and-merged code that isn't running in production, and nothing told you.

The correct range is the **full push**: `github.event.before..HEAD`.

```bash
BEFORE_SHA="${{ github.event.before }}"
# New branch or force push: before is all zeros → fall back to HEAD~1
if [ -z "$BEFORE_SHA" ] || [ "$BEFORE_SHA" = "0000000000000000000000000000000000000000" ]; then
  BEFORE_SHA="HEAD~1"
fi
git diff --name-only "$BEFORE_SHA" HEAD -- api/
```

This requires `fetch-depth: 0` on checkout — a shallow clone can't diff arbitrary ranges.

## Prerequisites

- Monorepo with services in separate directories (e.g. `api/`, `web/`)
- One Coolify app per service (see [two-apps-two-dockerfiles.md](two-apps-two-dockerfiles.md))
- The SSH deploy pattern from [cloudflare-bot-fight.md](cloudflare-bot-fight.md)

## Check

Look at your current workflow: does it deploy unconditionally, or diff with `HEAD~1`? Both are the problem.

## Apply

Use the `changes` job from [`deploy.yml`](../.github/workflows/deploy.yml). Rules for the path filters:

- **Shared files go in every filter.** Root `package.json`, the lockfile, shared configs — a dependency bump must redeploy everything that uses it.
- **Migrations belong in the API filter** (or whichever service runs them at startup).
- **Each service's Dockerfile goes in its own filter.**
- `workflow_dispatch` (manual run) deploys everything — your escape hatch when detection is ever in doubt.

## Verify

1. Push a commit touching only `web/` → Actions run shows Deploy API **skipped**, Deploy Web **ran**.
2. Push 2+ commits at once where only the *first* touches `api/` → Deploy API still runs. (This is the `HEAD~1` regression test.)

## Notes

- Coolify has a built-in "watch paths" feature per app — if your setup is simple, that may be enough. We do it in CI because deploys must be gated on tests passing anyway, and one gate is simpler than two.
