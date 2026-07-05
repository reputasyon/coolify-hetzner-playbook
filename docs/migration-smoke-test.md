# Catch broken migrations in CI, not in a production boot-loop

**Symptom:** you push a migration, CI is green (unit tests mock the DB), deploy succeeds — and the API container crash-loops because the migration SQL fails against a real PostgreSQL. Coolify keeps restarting it; your API is down until you ship a fix.

**Cause:** if migrations run at app startup (a good pattern — atomic with deploys), then production is the **first real database your migration ever touches**, unless CI provides one.

**Fix:** spin up a fresh PostgreSQL service container in CI and apply the *entire* migration chain (baseline → latest) to it on every push. Broken SQL now fails the build, and the deploy never happens.

## Prerequisites

- Sequential SQL migrations (`migrations/001_*.sql`, `002_*.sql`, ...) with a runner (we use [`postgres-migrations`](https://www.npmjs.com/package/postgres-migrations); anything with a CLI/`migrate` script works)
- A standalone migrate command, e.g. `npm run migrate` reading `DATABASE_URL`

## Check

Does your CI touch a real database anywhere? If tests are mock-based (fast, good) and nothing else applies migrations, you have this gap.

## Apply

In your test job (full workflow: [`deploy.yml`](../templates/deploy.yml)):

```yaml
services:
  postgres:
    image: postgres:16-alpine
    env:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app_test
    ports: ['5432:5432']
    options: >-
      --health-cmd pg_isready --health-interval 10s
      --health-timeout 5s --health-retries 5

steps:
  - name: Migration smoke test (fresh DB)
    env:
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/app_test
    run: npm run migrate
```

Match the `image:` tag to your production PostgreSQL major version — version drift here defeats the purpose.

## Verify

Add a deliberately broken migration on a branch (`SELCT 1;`), push, and watch the smoke-test step fail. Delete the branch. Now you trust the gate.

## Hard-won rules that pair with this

- **Never edit an applied migration.** Runners track checksums; a mismatch on a file that already ran will fail startup everywhere. Fix forward with a new migration.
- **Forward-only.** Don't build rollback machinery you'll never test — write the reversing migration when you actually need it.
- **The smoke test only proves SQL validity on an empty DB.** A migration can be valid SQL and still be wrong against production data (e.g. adding `NOT NULL` to a column with existing NULLs). For risky data migrations, also test against a production snapshot locally.

## Why we're strict about this

A migration that silently never ran in production cost us 16 hours of a stock-update function failing — see [the incident report](incidents/2026-04-broken-migration-pipeline.md).
