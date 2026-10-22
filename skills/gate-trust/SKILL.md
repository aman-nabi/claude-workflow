---
name: gate-trust
description: Let the Stop gate run a repo's check commands. The user runs this once per repo, and again whenever the repo's gate config changes.
disable-model-invocation: true
argument-hint: "<repo path, default the current repo>"
---

The Stop gate never runs commands from a repo's `.claude/workflow-gate.conf` until the user trusts that file. This protects against a cloned repo whose config runs something harmful.

1. Find the repo: the argument if given, otherwise the current repo.
2. Run, and show the user the whole output exactly as printed:

   ```
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/gate-trust.sh" --show "<repo>"
   ```

   It lists every command the gate would run (each step named in `STEPS`), the config id, and the git folder the trust covers (every worktree of that repo).
3. Ask: "Trust these commands for the Stop gate in every worktree of this repo?" Wait for a clear yes in chat.
4. On yes, run with the config id from step 2:

   ```
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/gate-trust.sh" "<repo>" "<config id>"
   ```

   If the config changed after step 2, the script refuses; start again at step 2. Show its output.

To remove trust, run the same script with `--revoke "<repo>"`. To see every trusted repo, run it with `--list`.
