---
name: plan-check
description: Run the contrarian agent on a plan before any test or code is written, for one graded round. Use in the normal and high flow after the plan exists, or when the user asks to stress-test a plan.
---

1. **Inputs.** Have ready:
   - the plan file;
   - the settled decisions from the grill, so they are not reopened;
   - the tier.
2. **Dispatch.** Start the `tiered-workflow:contrarian` agent with:
   - the plan text, or its path;
   - the settled decisions, marked as settled;
   - the calibration: normal tier is medium-stakes, high tier is high-stakes;
   - these extra asks:
     - "Read the plan a second time as someone new to it and flag any step that is unclear."
     - "List test cases the plan is missing."
3. **Sort the findings.**
   - **Critical or Major that change what the product does:** put each to the user as a grilling question, with your recommended answer.
   - **Critical or Major that are technical:** update the plan yourself.
   - **Missing test cases:** add them to the plan's test cases.
   - **Minor:** list them; act only when trivial.
4. **One round.** Do not run the check again on the revised plan. A second round needs the user's request.
5. **Record.** Add a line to the plan: `Plan check: <n> findings, <n> applied, <n> to the user, verdict <verdict>`.
