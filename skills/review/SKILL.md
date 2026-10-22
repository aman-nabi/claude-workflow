---
name: review
description: Review a change on two axes, Standards and Spec, with fresh read-only reviewers that never saw the work, for one graded round. Use after implementation in every tier, or when the user asks to review a branch, a PR or work in progress.
---

Adapted from Matt Pocock's `code-review` skill (MIT, see THIRD_PARTY_NOTICES.md). The changes:
- graded findings and a single round;
- no issue-tracker set-up;
- reviewers are read-only agents that read the diff from a file;
- a hollow-test check on the Spec axis.

## 1. Pin the change

- **The fixed point:** use the one the user names. Otherwise use the merge-base with the main branch, or `HEAD` for uncommitted work.
- **Check it:** confirm the ref resolves and the diff is not empty.
- **Save the diff:** write it to a file in the session scratchpad or temp folder (`git diff <fixed-point>` plus untracked files). Note the commit list. The reviewers read this file; they never run git.

## 2. Find the sources

- **Spec:** the plan file, the PR description, the user's request, and any ticket referenced in commits. When there is none, the Spec reviewer reports "no spec available" and checks only the hollow-test items.
- **Standards:**
  - every file that says how code is written here: CLAUDE.md, CONTRIBUTING.md, CODING_STANDARDS.md and similar;
  - plus the smell baseline below.

  A documented repo standard always overrides the baseline. Each smell is a judgement call, never a hard violation. Skip anything tooling already enforces.

Smell baseline (Fowler, _Refactoring_, ch. 3), each as *what it is* → *how to fix*:

- **Mysterious Name**: a name that doesn't reveal what it does or holds → rename it.
- **Duplicated Code**: the same logic shape in more than one hunk or file → extract it, call it from both.
- **Feature Envy**: a method that uses another object's data more than its own → move it onto that data.
- **Data Clumps**: the same few fields or params travelling together → bundle them into one type.
- **Primitive Obsession**: a primitive standing in for a domain concept → give the concept its own type.
- **Repeated Switches**: the same switch or if-cascade in several places → one shared map or polymorphism.
- **Shotgun Surgery**: one logical change forces scattered edits → gather what changes together.
- **Divergent Change**: one module edited for several unrelated reasons → split it.
- **Speculative Generality**: abstraction added for needs the spec doesn't have → delete it.
- **Message Chains**: long `a.b().c().d()` navigation → hide the walk behind one method.
- **Middle Man**: a function that mostly delegates → call the real target.
- **Refused Bequest**: an implementer that ignores most of what it inherits → use composition.

## 3. Start two reviewers

Start two `tiered-workflow:code-reviewer` agents in the background. If your setup allows only one agent launch per message, launch them back to back. Wait for both.

**Standards reviewer**, give it:
- the diff file path and the commit list;
- the standards files;
- the smell baseline pasted in full;
- the axis name "Standards";
- this extra brief: "Check every comment the diff adds:
  - Does it explain a why the code cannot show (a business rule, an outside constraint, a ticket or decision reference, a non-obvious workaround)?
  - Does it describe the code as it is now?
  - Is it short, and free of history, session talk, notes to the user and copied plan text?

  Report each comment that fails, as nice-to-have unless it is wrong about the code, in which case it is should-fix."

**Spec reviewer**, give it:
- the diff file path and the commit list;
- the spec (path or text);
- the axis name "Spec";
- this extra brief: "Also check the tests in the diff:
  - Do they test behaviour through public interfaces?
  - Do they mock the project's own code?
  - Do they recompute expected values the way the code does?
  - Could they never fail?
  - Are the plan's reload, back-button, double-submit, prefetch, time and contract cases covered?"

## 4. Act on the findings, one round

- Present both reports under `## Standards` and `## Spec`, without merging or reranking them.
- Fix every **critical** and **should-fix** finding that you can confirm. For one you believe is wrong, say why instead of fixing it.
- List **nice-to-have** findings for the user; don't act on them unless trivial.
- Do not run a second review round. If a critical fix changed the design, tell the user and let them decide on another round.

End with one line: the number of findings per axis and grade, the worst finding on each axis, and what you fixed.
