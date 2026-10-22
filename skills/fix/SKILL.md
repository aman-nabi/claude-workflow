---
name: fix
description: The small-tier flow. Use for a change whose whole diff fits in one sentence and touches no protected area, such as a copy change, a one-screen display fix or a small bug. Runs tier, a short grill, one regression test first, the fix in this session, the gate, a graded review, a screenshot and docs.
---

Follow the steps in order. Show evidence at each step; a claim without output is not evidence.

1. **Tier.** Call the Skill tool with `tiered-workflow:tier`. If the tier is not small, stop and use `tiered-workflow:feature`.
2. **Clarify.** Ask at most 3 questions, in the `tiered-workflow:grilling` format: numbered, each with your recommended answer, worded so "yes" accepts it. Ask none when the request is clear. Look facts up yourself; only decisions go to the user.
3. **The sentence.** Write `The change: <one sentence>` and `The test: <the one behaviour it checks>`. This is the plan.
4. **Regression test first.** Write one test for that behaviour, at the public seam, following the `tiered-workflow:tdd` rules:
   - no mocks of the project's own code;
   - expected values are literals from the request, never recomputed the way the code computes them.

   Run it and show that it fails for the right reason (an assertion, not a typo or import error). If it passes before the fix, the test or your reading of the bug is wrong: stop and say so.
5. **Fix.** Make the smallest change, in this session. Do not start an edit agent for a small change.
6. **Gate.** Run the test file and show it pass. The Stop hook also runs lint, typecheck, related tests and the comment check when you finish; if it blocks, fix the cause, never the test's expectations.
7. **Comment pass.** No comments by default. Re-read every comment you added and keep one only for a why the code cannot show, in one or two lines, describing the code as it is now. Remove narration, history, notes to the user and plan text. History goes in the commit message.
8. **Review.** Call the Skill tool with `tiered-workflow:review`. It runs one fresh, read-only reviewer covering Standards and Spec for one graded round. Fix critical and should-fix findings; list nice-to-have ones for the user.
9. **Screenshot.** If a screen changed, run the walkthrough command from the project profile, or open the screen yourself, and save a screenshot. Give its path in your summary.
10. **Docs.** If the change alters documented behaviour, update the living doc in the same change and follow the project's document rules.
11. **Stop.** Do not commit, push or deploy unless the user asked.

End with a short summary:
- tier and the sentence;
- the test, red then green;
- review findings and what you fixed;
- the screenshot path;
- docs touched;
- what the user should check on stage.
