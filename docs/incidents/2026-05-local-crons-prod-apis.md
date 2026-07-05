# The laptop that was secretly running production (May 2026)

**Impact:** ~48 hours investigating "impossible" data corruption: a product's stock kept resetting to a wrong value on the live marketplace. Multiple investigation sessions, and a 5-hour architectural refactor that — while genuinely useful — did not fix the problem, because the problem was one missing env guard.

## What happened

Our app syncs with third-party marketplace APIs (orders in, stock/prices out) via background cron jobs. To debug production issues locally, we had a script that pulled a copy of the production database to the local machine — **including the encrypted marketplace API credentials**.

So the local dev environment had: the same cron code, the same credentials, and stale data. Every time `npm run dev` ran, local crons woke up and **pushed stale stock values to the real marketplace**, fighting the production server in a slow-motion tug-of-war. From production's point of view, stock numbers were being overwritten by a ghost.

## Timeline

- **Day 1:** merchant reports a product's stock "randomly resets". Production logs show *our own API calls* setting the value — but no code path in production explains the timing.
- **Day 1-2:** deep investigation of the sync engine; a reservation-pattern refactor is designed and built on the theory of a race condition. The refactor is good engineering. It changes nothing.
- **Day 2:** someone notices the wrong values correlate with *local development sessions*. The laptop was the second writer.

## Root cause

Production credentials + production-shaped code + **no environment guard** = a second production system running on a laptop, unlabeled.

## Why it wasn't caught

The local crons weren't failing — they were *succeeding*. Nothing in the marketplace's API response distinguishes a legitimate push from a stale one. And "check the local env first" wasn't in anyone's debugging playbook; exotic race conditions were more interesting than boring config.

## What changed

1. **Outbound-side-effect jobs are OFF by default in dev.** Crons that talk to external APIs only start when `ENABLE_CRONS=true` is explicitly set. Harmless local cleanup workers stay on. Default-off, opt-in — never the reverse.
2. **Debugging order codified:** before theorizing about architecture, check the boring suspects — local env, env vars, last deploy, *who else has these credentials*.

## The takeaways

- Any dev environment holding production credentials **is** production. Guard it like production or don't give it the credentials.
- When production data changes "impossibly", ask *"what else can write here?"* before *"what race condition explains this?"*. The five-minute question beats the five-hour refactor.
