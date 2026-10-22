# Workflow profile: <project name>

Copy to `<repo>/.claude/workflow-profile.md` and fill it in. The tiered-workflow skills read this file. Keep it short. Never put a password, key or token in it; name where the secret lives instead.

| Version | Date | Change |
|---|---|---|
| 1.0.0 | <yyyy-mm-dd> | First version. |

## Repos

- `<repo>`: <what it is>

## Protected areas

A change touching any of these is high tier. Name real paths so the tier can be checked against the diff.

- Sign-in and sessions: `<paths>`
- Money: `<paths>`
- Personal data: `<paths>`
- Stored data (schema, migrations): `<paths>`
- Infrastructure (deploy, CI, config, secrets): `<paths>`
- Logging and audit: `<paths>`

## Commands

- Lint: `<command>`
- Typecheck: `<command>`
- Related tests: `<command>`
- Full suite: `<command>`
- Mutation testing (high tier, optional): `<command>`
- Known failing tests before any change (baseline): `<where the list lives>`

## Walkthrough and screenshots

- Headed walkthrough: `<command>`
- Walkthrough helpers the walkthrough writer reuses: `<files>`
- Screenshots saved to: `<folder>`

## Agents: model and effort

Effort follows how settled the work is, never how big it looks. Once the plan is locked, the copying jobs need no deep reasoning.

| Role | Model | Effort |
|---|---|---|
| Plan check (contrarian) | `<model>` | high |
| Test writer | `<model>` | medium |
| Builder | `<model>` | medium, high for sign-in or money code |
| Docs writer | `<model>` | medium |
| Walkthrough writer | `<model>` | medium |
| Reviewer | `<model>` | high |

## Stage

- URLs: `<urls>`
- Smoke suite: `<command>`, run by `<deploy script>` after every deploy
- Smoke test account: secret stored in `<server env or pipeline secured variable>`, never in the repo

## Docs and records

- Living docs: `<folder>`
- Document rule: `<for example: new versioned file per edit, with changelog>`
- Plans: `.claude/plans/`
- Change records: `<PR, ticket system and key prefix>`
