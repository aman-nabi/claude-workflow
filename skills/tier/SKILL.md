---
name: tier
description: Classify a change as small, normal or high before any work starts, using the project's protected areas. Use at the start of every fix or feature, and whenever a change grows while you work on it.
---

Read the project profile at `.claude/workflow-profile.md`. If it is missing, use the default protected areas below and tell the user the profile is missing.

## The three tiers

- **High**: the change touches any protected area, spans more than one repo, or changes stored data (schema, migration, backfill).
- **Small**: all of these hold:
  - you can describe the whole code change in one plain sentence;
  - it touches no protected area;
  - it stays in one repo and is easy to revert;
  - it adds no new screen or flow.
- **Normal**: everything else.

When unsure between two tiers, pick the higher one. Size never lowers a tier: a one-line change to sign-in is high.

## Default protected areas

Use these when the profile lists none:

- sign-in, sessions, tokens, cookies, redirects, account set-up and recovery;
- money: payments, invoices, refunds, prices, anything that shows or decides what someone owes;
- personal data: names, emails, phone numbers, identity documents, member numbers;
- stored data: schema, migrations, backfills, data deletion;
- infrastructure: deploy scripts, server and service config, CI, secrets, permissions;
- logging, monitoring and audit trails.

## Output

Reply in this shape, then wait for the user before starting the flow:

```
Tier: <small | normal | high>
Why: <one sentence>
Protected areas touched: <list, or none>
The user can raise the tier; it is never lowered.
```

Record the tier where the project keeps change records: the PR description, or a `Tier: <tier>` line in the commit message when there is no PR.

If the change grows into a protected area while you work, say so, raise the tier, and switch to the matching flow (`tiered-workflow:fix` for small, `tiered-workflow:feature` for normal and high).
