# Changelog

## 1.0.0 (2026-10-22)

First version.

- **Skills:**
  - `tier`, `fix`, `feature`, `plan-check`, `tests-first`, `review` and `gate-trust`;
  - `grilling`, `grill-me`, `tdd` and `handoff`, copied from Matt Pocock's skills at commit `5beb35b`; `review` is adapted from his `code-review`.
- **Agents:**
  - `test-writer` and `code-reviewer`;
  - `contrarian`, copied from aaddrick/contrarian at commit `6dc3b8c` and made read-only.
- **Hooks:**
  - `turn-start.sh` (UserPromptSubmit) records each gated repo at the user's prompt;
  - `stop-gate.sh` (Stop) checks only the files changed during the turn. It runs lint, typecheck and related tests once the user has trusted the repo's config, then the comment check, and blocks until they pass.
  - The gate also has:
    - an attempt cap per prompt;
    - process-group timeouts;
    - a one-turn pause marker;
    - multi-repo host folders;
    - off switches.
- **Comment check** (`scripts/comment-check.sh`): flags comments added during the turn that carry history or session talk, dated change notes, TODOs without a ticket, dividers or long blocks. Ordinary domain phrases are left out, and `comment-check: allow` skips a line.
- **Docs:**
  - the workflow (`docs/workflow-v1.0.0.md`);
  - the draft change procedure (`docs/change-procedure-v1.0.0.md`, not yet approved).
- **Templates:**
  - the project profile;
  - the gate config;
  - the CLAUDE.md rules.
- **Tests:** `tests/stop-gate.test.sh`, 35 cases, passing on macOS bash 3.2.
- **Review:** one independent review round before release. Its findings were fixed:
  - the gate checked the whole dirty tree;
  - commands ran without trust;
  - timeouts left child processes running;
  - config parsing;
  - the tests-first conflict;
  - comment false alarms;
  - docs that did not match the code.
