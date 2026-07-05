# Contributing

This playbook grows one production scar at a time. The bar for inclusion is simple: **it must have actually happened, and the fix must be tested on a real server.** No theoretical best practices, no "you should probably also...".

## What we want

- **New gotchas** — a Coolify/VPS production problem not covered in `docs/`. Open an issue first with the symptom + root cause; we'll agree on scope before you write the doc.
- **Incident write-ups** — the highest-value contribution. Use the template below.
- **Corrections** — a doc's fix didn't work on your setup, a command changed in a newer Coolify version, a better permanent fix exists. PR directly.
- **Translations** — currently EN + TR. A new language means committing to keep it in sync.

## What we don't want

- Link lists / awesome-list entries
- Tool recommendations without an operational lesson attached
- AI-generated docs for problems you haven't personally hit (we can generate those ourselves — the value here is that everything is lived)

## Doc format (required)

Every guide follows the agent-ready structure so both humans and AI assistants can execute it:

```markdown
# Symptom-first title

**Symptom:** what the user sees.
**Cause:** why it happens.

## Prerequisites
## Check      ← commands to detect whether the problem/config applies
## Apply      ← the fix, idempotent where possible
## Verify     ← commands + expected output proving it worked
## Notes
```

## Incident report format

`docs/incidents/YYYY-MM-short-slug.md`:

```markdown
# Catchy but honest title (Month Year)

**Impact:** what it cost — downtime, data, hours.

## What happened
## Timeline        ← T+0 style
## Root cause      ← the systemic one, not the typo
## Why it wasn't caught
## What changed    ← the permanent fixes, linked to docs/
## The takeaway
```

Blameless. Anonymize freely (company/product names), but keep the technical details exact — vague incidents teach nothing.

## Process

1. Issue first for new docs/incidents (skip for small corrections).
2. PR with one logical change.
3. Test commands on a real Ubuntu/Debian server before submitting. State the Coolify version you tested against.
