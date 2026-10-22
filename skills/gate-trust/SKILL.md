---
name: gate-trust
description: Let the Stop gate run a repo's lint, typecheck and test commands. The user runs this once per repo, and again whenever the repo's gate config changes.
disable-model-invocation: true
argument-hint: "<repo path, default the current repo>"
---

The Stop gate never runs commands from a repo's `.claude/workflow-gate.conf` until the user trusts that file. This protects against a cloned repo whose config runs something harmful.

1. Find the repo: the argument if given, otherwise the current repo.
2. Read `<repo>/.claude/workflow-gate.conf` and show the user its `LINT_CMD`, `TYPECHECK_CMD` and `TEST_CMD` lines exactly as written.
3. Ask: "Trust these commands for the Stop gate in this repo?" Wait for a clear yes in chat.
4. On yes, run:

   ```
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/gate-trust.sh" "<repo>"
   ```

   Show its output.

To remove trust, run the same script with `--revoke "<repo>"`. To see every trusted repo, run it with `--list`.
