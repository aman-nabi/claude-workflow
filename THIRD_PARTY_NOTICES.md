# Third-party notices

This plugin includes files copied from two open-source projects, pinned at the commits below. The unchanged originals are kept in `vendor/`, so every "Changes" entry can be checked with a diff. Updates are taken on purpose, never automatically: re-copy at a new commit, review the diff, and record it in CHANGELOG.md.

## Matt Pocock, skills

- Source: https://github.com/mattpocock/skills
- Commit: `5beb35b040e3de97e54fa9e386d7e42d15c295c2` (2026-10-19)
- Licence: MIT, full text in `vendor/mattpocock-skills/LICENSE`. Copyright (c) 2026 Matt Pocock.

| File here | Source file | Changes |
|---|---|---|
| `skills/grilling/SKILL.md` | `skills/productivity/grilling/SKILL.md` | None |
| `skills/grill-me/SKILL.md` | `skills/productivity/grill-me/SKILL.md` | Calls `tiered-workflow:grilling` |
| `skills/tdd/SKILL.md` | `skills/engineering/tdd/SKILL.md` | The `codebase-design` reference is replaced by a grilling question; a paragraph places the skill as the inner loop after `tests-first`; points to `tiered-workflow:review` |
| `skills/tdd/tests.md` | `skills/engineering/tdd/tests.md` | None |
| `skills/tdd/mocking.md` | `skills/engineering/tdd/mocking.md` | None |
| `skills/handoff/SKILL.md` | `skills/productivity/handoff/SKILL.md` | None |
| `skills/review/SKILL.md` | `skills/engineering/code-review/SKILL.md` | Rewritten around the original's two axes and smell baseline: graded findings, one round, no tracker set-up, read-only reviewers, a hollow-test check. The original is kept at `vendor/mattpocock-skills/code-review-SKILL.md` |

## aaddrick, contrarian

- Source: https://github.com/aaddrick/contrarian
- Commit: `6dc3b8c6ff744b0f875264d7124aab83cdb76db0` (2026-10-07)
- Licence: Unlicense (public domain), full text in `vendor/contrarian/UNLICENSE`.

| File here | Source file | Changes |
|---|---|---|
| `agents/contrarian.md` | `.claude/agents/contrarian.md` | Adds `tools: Read, Grep, Glob` so the agent is read-only; long dashes replaced with hyphens |
