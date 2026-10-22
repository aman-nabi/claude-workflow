# Changelog

## 1.2.0 (2026-10-22)

A faster flow: the careful steps stay, each done once, with tight briefs and work in parallel. Built after a batch of six fixes took 6.5 hours, about 30 minutes of it coding. Reasons and sources are in `docs/workflow-v1.1.0.md`.

- **The feature flow runs in four stages.**
  - **A, agree:** a tier per fix, one grill round for the whole batch, and a plan written once and locked. The user reads the "user should see" and "behind the scenes" lists. The plan check is high tier only, and skipped when every decision is already settled.
  - **B, build in parallel:** the test writer, one builder per repo, the docs writer and the walkthrough writer start at the same time, each in its own worktree.
  - **C, check once:** tests red on the old code, then green on the new, the break check, one review per repo, the full suite once, and a walkthrough table with evidence per line.
  - **D, close out:** the hand-off, then five minutes on what cost time; a mistake seen twice becomes a hook or a check.
- **`templates/plan-template.md`:** per fix, the tier, the "user should see" and "behind the scenes" lists, the names both sides build to, the exact files touched, the docs, stage times and the follow-up list.
- **`scripts/agent-worktree.sh`:** `create` gives each parallel agent a detached worktree beside the repo; `collect` copies its changes in, uncommitted, and refuses a clash.
- **`scripts/test-lock.sh`,** a PreToolUse hook: it refuses edits to the tests listed in `<git-dir>/tiered-workflow-locked-tests`, and to the lock and unlock files themselves. Only the user lifts the lock, for one turn. The Stop gate ends the unlock in every repo the turn reaches, gated or not, even with the gate off, and says so, also when it blocks. Edits made through the shell are not seen by the hook.
- **Collecting a worktree** diffs from the commit it started at, so a commit an agent made in it is not lost.
- **Comments:** no comments by default. The comment check now flags a block longer than 2 lines (was 8) and a file that gains more than 6 comment lines in one turn (`COMMENT_MAX_PER_FILE`).
- **Review:** one reviewer per repo covers Standards and Spec; findings that do not block go to the plan's follow-up list.
- **Test writer:** works from the plan's lists and names only, in its own worktree, one test per list line.
- **Profile:** a model and effort table per role.
- **Feature flow, after review:** when a test writer runs, the main session builds in a worktree too; every worktree is collected before the one review, so docs and the walkthrough script are reviewed with the code.
- **Upgrading from 1.1.0:** a repo that relied on 8-line comment blocks sets `COMMENT_MAX_LINES` in its gate config. The new hook needs no trust, because it runs no repo commands.
- **Tests:** 78 cases. Independent review: one round, both axes. Five should-fix findings fixed, each with a test shown red by a deliberate break. One finding was not taken: normal tier keeps the test with the fix, as the owner decided.

## 1.1.0 (2026-10-22)

Set-up for real multi-package, multi-worktree projects.

- **`STEPS`** names the gate's steps and their order, each with its own `<NAME>_CMD`.
- **`{files:<folder>}`** passes only the changed files inside that folder, and every placeholder in a command is filled. A command whose placeholder has no files is skipped.
- **`scripts/tsc-changed.sh`**, reachable as `$TIERED_WORKFLOW_SCRIPTS/tsc-changed.sh`, fails only on type errors in the changed files, so errors that already exist on main do not block. It fails when tsc cannot run, when its output cannot be read, and when tsc checked no file in the folder (a solution-style tsconfig).
  - **Limit:** an error the change causes in a file it did not touch, such as a caller broken by a changed signature, does not block here. The full typecheck at review catches it. An error already in a touched file does block; the block message tells Claude to report it, not change the user's work.
- **`REPOS`** accepts patterns such as `tmp/*/app`, read from the host folder.
- **Trust is recorded per git folder**, so one trust covers every worktree of a repo. A separate clone needs its own trust, because an origin URL is local config that any folder can claim.
- **`gate-trust.sh --show`** prints every command named in `STEPS` and the folder the trust covers, and changes nothing. Trusting takes the config id that `--show` printed, and is refused if the config changed in between.
- **Config keys are matched as plain text.** Step names come from the config before it is trusted; a crafted name could run as a sed command before.
- **Upgrading from 1.0.0:** trust records from 1.0.0 are keyed by path, so trust each repo again.
- **Tests:** 54 cases.

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
