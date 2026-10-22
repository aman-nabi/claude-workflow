---
name: feature
description: The normal and high tier flow. Use for features, changes across several files, and anything that touches a protected area (sign-in, money, personal data, stored data, infrastructure). Runs tier, grill, a short plan, the contrarian plan check, acceptance tests first, test-driven build, the gate, proof the tests are real, a graded review, screenshots, docs and the stage hand-off.
---

Follow the steps in order. Show evidence at each step; a claim without output is not evidence.

1. **Tier.** Call the Skill tool with `tiered-workflow:tier`. If the tier is small, use `tiered-workflow:fix` instead.
2. **Grill.** Call the Skill tool with `tiered-workflow:grilling`. Keep normal changes to about 5 to 8 questions in total; high changes take as many rounds as they need. Facts you look up yourself; decisions go to the user.
3. **Plan.** Write a short plan where the project profile says plans live (default `.claude/plans/<yyyy-mm-dd>-<slug>.md`). It holds:
   - the goal in one sentence;
   - what changes, per repo;
   - the settled decisions from the grill;
   - **test cases**: what must work, what must be refused, and any of these that apply:
     - reload and the back button on any page with a one-time action;
     - double submit;
     - a GET that changes data (it must not, since links are prefetched);
     - time-based rules, using a controllable clock;
     - data crossing services (the contract);
   - out of scope.

   For high, add a design note:
   - data touched;
   - security and privacy;
   - failure modes;
   - rollout and rollback;
   - whether personal-data handling changes (if it does, flag a DPIA check);
   - which docs change.
4. **Plan check.** Call the Skill tool with `tiered-workflow:plan-check`. One round. Findings that change what the product does go to the user; technical fixes and missing test cases go into the plan.
5. **Tests first.** Call the Skill tool with `tiered-workflow:tests-first`. The acceptance tests come from the plan, not from code, and must fail before you build.
6. **Build.** Work in vertical slices with `tiered-workflow:tdd`: one failing test, the least code to pass it, repeat.
   - Do the work in this session when it fits.
   - For big or multi-repo work, use one edit agent per repo. Its brief lists the edits with file anchors and the tests to satisfy. The main session runs every check.
7. **Gate.**
   - The Stop hook runs lint, typecheck, related tests and the comment check.
   - Run the full suite for each touched package and compare it with the baseline from before your change. Name any failure that existed before.
8. **Prove the tests are real.** For each acceptance test, make one deliberate break in the code (flip a condition, return early, drop a line), show the test go red, then undo the break. For high, also run the profile's mutation command on the changed files when it has one. Delete or rewrite any test that never goes red.
9. **Comment pass.** Re-read every comment you added. Keep only a why the code cannot show (a business rule, an outside constraint, a ticket or decision reference, a non-obvious workaround), describing the code as it is now in one or two lines. Remove narration, history, notes to the user, and plan or design text copied into code; link to the plan or doc instead. The Stop gate's comment check catches the common cases.
10. **Review.** Call the Skill tool with `tiered-workflow:review`. One graded round; fix critical and should-fix findings.
11. **Screenshots.** Run the headed walkthrough of each changed journey (the profile's walkthrough command) and save screenshots of every changed screen for the user's first look.
12. **Docs.** Update the living docs in the same change, following the project's document rules. Add a changelog entry when the project keeps one.
13. **Stage hand-off.** Say what the stage smoke suite will check and what the user should walk by hand. For high, note that the change needs the approvals the change procedure sets. Do not commit, push or deploy unless the user asked.

End with a short summary:
- tier, the plan's path, and the plan-check outcome;
- the tests, red then green;
- the break check;
- review findings and fixes;
- the screenshot paths;
- docs touched;
- the stage checklist.
