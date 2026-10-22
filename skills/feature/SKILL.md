---
name: feature
description: The normal and high tier flow. Use for features, changes across several files, and anything that touches a protected area (sign-in, money, personal data, stored data, infrastructure). Runs in four stages - agree (tier per fix, one grill round, one locked plan, the user's list check, a plan check for high), build in parallel (test writer, builders, docs and walkthrough writers in their own worktrees), check once (red on old code, green on new, break check, one review per repo, full suite, walkthrough with evidence), and close out.
---

Follow the stages in order. Show evidence at each step; a claim without output is not evidence. Log each stage's start and end time in the plan, such as `Stage A: 10:05 to 10:30`.

## Stage A: agree what to build (you and the user)

1. **Tier each fix.** Call the Skill tool with `tiered-workflow:tier` for each fix in the request, not once for the batch. Small fixes go to `tiered-workflow:fix`; the rest stay here.
2. **Grill, one round.** Call the Skill tool with `tiered-workflow:grilling`, then put every question of the whole batch to the user in one message, each with your recommended answer. Look facts up yourself first: the code, the docs, how the other products already behave. Ask a second round only for a question that one of the answers opened.
3. **Plan, written once.** Copy `templates/plan-template.md` from this plugin to where the project profile says plans live (default `.claude/plans/<yyyy-mm-dd>-<slug>.md`). Fill it from the answers in one edit; do not start a new plan version per answer. For each fix it holds:
   - the tier;
   - **the user should see**: plain sentences a person can check, such as "press Back, see Taking you to IDfied with a Continue button". Include reload, the back button, double submit, a GET that must change nothing, time rules and data crossing services where they apply;
   - **behind the scenes**: results to check in data or logs, such as "one set-up record, not two";
   - **names both sides build to**: routes, fields, button labels, page titles, test helpers;
   - **touches**: the exact files, sections and helpers.

   For high, add the design note in the template.
4. **The user reads the lists.** Show the user the "user should see" and "behind the scenes" lists and wait for a yes. Gaps are cheapest to catch here.
5. **Plan check, high only.** Call the Skill tool with `tiered-workflow:plan-check`, one round. Skip it when every decision is already settled with the user. Product findings go to the user as one grill round; technical ones go into the plan.
6. **Lock the plan.** From here every brief is copied from the plan. A change to what the product does goes back to the user, never silently into a brief.

Start Stage B in a fresh session when this one is long; the plan carries everything across.

## Stage B: build in parallel

7. **One worktree per agent.** For each agent, run `bash <plugin>/scripts/agent-worktree.sh create <repo> <name>` and give the agent only that path. `<plugin>` is two folders up from this skill's base directory. Agents never see each other's work, and the Stop gate never checks a half-finished edit.
8. **Start these at the same time,** in one message:
   - **test writer** (high tier): `tiered-workflow:tests-first`, briefed only with the plan's lists and names;
   - **one builder per repo**, or the main session for work that fits it: the plan's touches list, the names and the edits. When a test writer runs, the main session builds in a worktree of its own too, so the repo keeps the old code for the red run;
   - **docs writer**: the plan's docs list with the exact files and sections, at medium effort;
   - **walkthrough writer** (high and normal): the "user should see" list and the project's walkthrough helpers.

   Every brief carries the hard rules:
   - edit only inside your worktree;
   - no git commits, stash or reset;
   - run nothing;
   - no comments by default, and only a one- or two-line why when the code cannot show it;
   - reply with the files touched.

   For normal tier, the builder may write its own regression test with the fix; the review is the independent check.

## Stage C: check once

9. **Red on the old code.** Collect the test writer's worktree first (`agent-worktree.sh collect <repo> tests`), while the repo still holds the old code. Run the new tests: each must fail for the right reason. Then lock them as `tiered-workflow:tests-first` says.
10. **Green on the new code.** Collect each builder's worktree, then the docs and walkthrough writers'. Run the related tests: each must pass. When one fails, the plan decides:
    - the code does not match the plan: fix the code;
    - the test's setup is wrong, or the plan did not say: ask the user, since the test is locked.
11. **Prove the tests are real.** For each acceptance test, make one deliberate break in the code (flip a condition, return early, drop a line), show the test go red, then undo the break. For high, also run the profile's mutation command when it has one.
12. **Docs check.** Check the docs writer's files against the plan's names. Add a changelog entry when the project keeps one.
13. **One review,** of everything collected: code, tests, docs and the walkthrough script. Call the Skill tool with `tiered-workflow:review`: one reviewer per repo, both axes, one round. Fix critical and should-fix findings. Anything else, and any new request, goes on the plan's follow-up list.
14. **Full suite once** for each touched package, in the background or by CI on push, compared with the baseline from before the change. Name every failure that existed before.
15. **Walkthrough.** Run the walkthrough headed. The result is a table in the plan: one row per "user should see" and "behind the scenes" line, pass or fail, with its screenshot or output.

## Stage D: close out

16. **Hand-off.** Say what the stage smoke suite will check and what the user should walk by hand. For high, note the approvals the change procedure sets. Do not commit, push or deploy unless the user asked.
17. **Learn, five minutes.** List what cost time or was corrected in this run. A mistake that happened twice becomes a hook or a check, not a note. Remove notes and version copies that are now stale.

End with a short summary:
- each fix's tier, the plan's path and the plan-check outcome;
- the stage times;
- the tests, red on old code then green on new;
- the break check;
- review findings, fixes and the follow-up list;
- the walkthrough table;
- docs touched;
- the stage checklist.
