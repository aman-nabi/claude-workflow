# tiered-workflow

A Claude Code plugin that runs one workflow in every project. Small fixes stay fast, risky changes get the full process, and a change is checked against real behaviour before a person tries it.

The plugin is named `tiered-workflow` because Claude Code reserves plugin names that start with `claude-`. This repo is `claude-workflow`.

The workflow itself is in [docs/workflow-v1.0.0.md](docs/workflow-v1.0.0.md). The change procedure it supports (draft, not yet approved) is in [docs/change-procedure-v1.0.0.md](docs/change-procedure-v1.0.0.md).

## What's inside

| Part | Name | What it does |
|---|---|---|
| Skill | `/tiered-workflow:tier` | Classifies a change as small, normal or high from the project's protected areas |
| Skill | `/tiered-workflow:fix` | The small-tier flow |
| Skill | `/tiered-workflow:feature` | The normal and high flow |
| Skill | `/tiered-workflow:grill-me`, `grilling` | Questions in rounds, each with a recommended answer (Matt Pocock) |
| Skill | `/tiered-workflow:plan-check` | One graded contrarian round on the plan |
| Skill | `/tiered-workflow:tests-first` | A separate agent writes acceptance tests from the plan, then they are shown failing |
| Skill | `/tiered-workflow:tdd` | The red, green loop for building in vertical slices (Matt Pocock) |
| Skill | `/tiered-workflow:review` | Two fresh read-only reviewers (Standards, Spec), graded, one round |
| Skill | `/tiered-workflow:handoff` | A short hand-off note for starting a fresh session (Matt Pocock) |
| Agent | `contrarian` | Read-only plan critic (aaddrick/contrarian) |
| Agent | `test-writer` | Writes tests from the request and plan, never from the code |
| Agent | `code-reviewer` | Read-only reviewer for one axis |
| Skill | `/tiered-workflow:gate-trust` | You run it once per repo to let the Stop gate run that repo's commands |
| Hook | Turn start (UserPromptSubmit) | Records each gated repo at your prompt, so the gate checks only what changed during the turn |
| Hook | Stop gate | When Claude ends a turn, checks the files changed since your prompt: lint, typecheck, related tests and the comment check. A failure keeps Claude working, up to 3 times per prompt |
| Script | `scripts/comment-check.sh` | Flags the added comments that users complain about: history, dated change notes, TODOs without a ticket, dividers, long blocks |

## Install

From a terminal, once per Claude Code login:

```
claude plugin marketplace add aman-nabi/claude-workflow
claude plugin install tiered-workflow@aman-nabi
```

Or inside a session: `/plugin marketplace add aman-nabi/claude-workflow`, then `/plugin install tiered-workflow@aman-nabi`.

## Set up a project

1. Copy `templates/workflow-profile.md` to `<repo>/.claude/workflow-profile.md` and fill it in: the protected areas with real paths, the commands, the stage URLs and where docs live.
2. Copy `templates/workflow-gate.conf` to `<repo>/.claude/workflow-gate.conf` and set the lint, typecheck and test commands. Without this file the Stop gate does nothing in that repo.
3. Run `/tiered-workflow:gate-trust` in the repo. The gate never runs a repo's commands until you have trusted its config, and asks again whenever the config changes. The comment check needs no trust, because it runs no repo commands.
4. Keep build output and test artifacts in `.gitignore`. The gate treats a new untracked file as a change.
5. Commit both files.
6. Paste the block from `templates/claude-md-rules.md` into the global CLAUDE.md of each Claude Code login, or into the project's CLAUDE.md.

For a folder that holds several repos and is not a git repo itself, put a `workflow-gate.conf` with `REPOS=<relative paths>` at the folder's `.claude/`, plus one in each repo.

The gate's switches:
- **Off everywhere:** set `CLAUDE_WORKFLOW_GATE=off` in the environment.
- **Off for one repo:** `GATE_ENABLED=0` in the repo's config.
- **Paused for one turn:** create `tiered-workflow-pause` in the repo's git dir. The tests-first skill does this when it must stop with tests red on purpose, and you are told each time.

## Test the gate

```
bash tests/stop-gate.test.sh
```

The tests build throwaway git repos in a temp folder and check the gate's behaviour:
- **Scope:**
  - silent when not configured or nothing changed;
  - the user's own work is never checked;
  - multi-repo host folders.
- **Blocking:**
  - a block on failure, with valid JSON;
  - the attempt cap;
  - trust, and trust again after a config change;
  - the pause marker;
  - timeouts that kill child processes.
- **Input handling:**
  - paths with spaces;
  - config quoting and CRLF;
  - the comment check's flags and its false-alarm cases.

## Updating

- Bump `version` in `.claude-plugin/plugin.json` and add a CHANGELOG entry for every change. Installed copies stay on their version until it changes.
- The third-party files are pinned copies; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Update them on purpose, never automatically.
- This plugin is part of the change-management scope. Changes to it follow the change procedure like any other code.
