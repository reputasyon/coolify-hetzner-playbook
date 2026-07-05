# Incident reports

Real production incidents from running a revenue-generating SaaS on Coolify + a small VPS. Anonymized, but nothing else softened — the point is that every rule in this playbook was paid for.

| Incident | Impact | Rule it produced |
|----------|--------|------------------|
| [Migration silently never ran in prod](2026-04-broken-migration-pipeline.md) | 16h of failed stock restores, manual data repair | Migration smoke test in CI ([doc](../migration-smoke-test.md)) |
| [Local dev crons pushed to real third-party APIs](2026-05-local-crons-prod-apis.md) | 48h of "ghost" data corruption investigations | Background jobs OFF by default in dev |
| [Combined Dockerfile took the whole site down](2026-06-combined-dockerfile-outage.md) | Full outage | One service per Coolify app ([doc](../two-apps-two-dockerfiles.md)) |

Writing template for contributions: **What happened → Timeline → Root cause → Why it wasn't caught → What changed.** Blameless, specific, reproducible.
