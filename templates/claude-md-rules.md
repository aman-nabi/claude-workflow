# tiered-workflow rules for CLAUDE.md

Paste the block below into the global CLAUDE.md of each Claude Code login, or into a project's CLAUDE.md. Keep it short: the Stop gate and the review enforce these rules, so this text only has to explain them.

```markdown
## Workflow (tiered-workflow plugin)
- Before any change, name its tier with /tiered-workflow:tier. Small changes use /tiered-workflow:fix; normal and high use /tiered-workflow:feature.
- A small change is made in the main session. An edit agent is for big or multi-repo work.
- Tests come from the request and plan, are shown failing first, and are never changed to match the code.
- "Done" means the Stop gate passed. Never claim a check passed without its output.

## Code comments
- Write a comment only for a why the code cannot show: a business rule, an outside constraint, a ticket or decision reference, or a non-obvious workaround.
- Describe the code as it is now. When and why it changed belongs in the commit message.
- Write for a reader who has never seen this session or the plan, and never address the user.
- One or two lines per comment. A docstring is one summary sentence, plus parameters when they need explaining. Link to the design doc instead of copying it.
- A TODO carries a ticket ID.
- Before finishing, re-read every comment you added against these rules.

Good: `// The provider bans an account after 5 failed logins, so retries stop at 3.`
Not this: `// Updated to use a sliding window as requested. Previously we used a fixed window, which caused the bug.`
```
