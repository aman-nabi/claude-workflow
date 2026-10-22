---
name: tests-first
description: Have a separate agent write the acceptance tests from the plan's lists only, in its own worktree and in parallel with the build, then prove they fail on the old code, pass on the new code, and lock them. Use in the high flow after the plan is locked.
---

Tests written in the same session as the code assert what the code does, so they pass by construction. This step keeps the author of the tests away from the code being written.

1. **Brief.** Start the `tiered-workflow:test-writer` agent in its own worktree (`agent-worktree.sh create <repo> tests`), at the same time as the builders. Give it only:
   - the worktree path;
   - the plan's "user should see" and "behind the scenes" lists;
   - the names both sides build to;
   - where the tests belong: the files, the public interfaces or seams, the framework and its conventions, the helpers to reuse;
   - the requirement or ticket IDs to put in test names.

   Never give it the build briefs, the builders' worktrees or a description of the code.
2. **Run red on the old code.** Collect the test worktree before any builder's (`agent-worktree.sh collect <repo> tests`). Run the new tests. Every one must fail for the right reason: an assertion or a missing export, not a syntax or setup error. Show the output.
3. **Lock them.** Write the new test files, one repo-relative path per line, to `$(git rev-parse --absolute-git-dir)/tiered-workflow-locked-tests`. The test-lock hook then refuses every edit to them. Only the user lifts the lock, by creating `tiered-workflow-tests-unlocked` in the same git dir; it lasts one turn and the user is told.
4. **Fix the code, never the test.** When a locked test fails on the new code, fix the code to the plan. When you think the test's setup or expectation is wrong, stop and ask the user.

   The Stop gate blocks a turn that ends with failing tests. When you must stop while tests are red on purpose (to show them, or to ask the user), pause the gate for that one turn first:

   ```
   touch "$(git rev-parse --absolute-git-dir)/tiered-workflow-pause"
   ```

   Do this only for that reason. The user is told the gate was paused, and it checks again on the next turn.
5. **Record.** Note in the plan which tests were written, the red result on the old code, and the locked list. Delete the lock file after the review, when the change is ready to commit.
