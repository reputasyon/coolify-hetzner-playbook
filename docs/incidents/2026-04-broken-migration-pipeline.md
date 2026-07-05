# The migration that never ran (April 2026)

**Impact:** a core stock-tracking function failed silently in production for ~16 hours. Five cancelled orders never got their stock restored to inventory. Manual data repair required, plus a full audit of what else might have drifted.

## What happened

Our schema lived in two places: `.sql` files in a `migrations/` folder, and — this is the bug — the *actual* runtime schema setup as inline SQL in application code. The `.sql` files were **documentation**, not executed by anything. Everyone (including the AI assistants working on the codebase) assumed writing a migration file meant it would run.

A new feature added an `inventory_logs` audit table via a migration file. Locally it existed (created manually during development). In production, nothing ever created it. The stock-restore code path did `INSERT INTO inventory_logs ...` inside the same transaction as the stock update — the INSERT failed, the transaction rolled back, and **the stock restore rolled back with it**.

## Timeline

- **T+0:** deploy ships. Unit tests green (mock-based — no real DB in CI at the time).
- **T+0 → T+16h:** every order cancellation logs an error server-side; nobody is watching that log stream. Stock numbers quietly drift from reality.
- **T+16h:** a warehouse discrepancy report ("system says 0, shelf has 5") triggers investigation. Error logs reveal `relation "inventory_logs" does not exist`.
- **T+17h:** table created manually, stock manually reconciled from order history.

## Root cause

Not the missing table — the **split-brain schema pipeline** that made "migration exists" and "migration ran" two different things with no check connecting them.

## Why it wasn't caught

1. CI had no real database; mocks don't validate SQL against schema.
2. Migrations weren't executed by a runner — no source of truth for "applied".
3. The failing code path (order cancellation) is low-frequency; errors landed in logs nobody tails.

## What changed

1. **A real migration runner** ([postgres-migrations](https://www.npmjs.com/package/postgres-migrations)) executing `migrations/*.sql` at API startup, tracking applied files with checksums, advisory-locked against concurrent starts. One pipeline, no split brain.
2. **Migration smoke test in CI** — the full chain runs against a fresh PostgreSQL on every push ([doc](../migration-smoke-test.md)). The exact failure class is now a red ✗ on the PR instead of a production incident.
3. **Error monitoring (Sentry)** so that "errors landing in logs nobody reads" stops being a failure mode.

## The takeaway

If migrations "run at startup", verify the runner actually reads your files — in a fresh environment, not the one where you created tables by hand during development. The database you develop against is full of lies.
