---
name: tests-first
description: Have a separate agent write the acceptance tests from the request and plan only, before the implementation exists, then prove they fail. Use in the normal and high flow after the plan check.
---

Tests written in the same session as the code assert what the code does, so they pass by construction. This step keeps the author of the tests away from the code being written.

1. **Brief.** Start the `tiered-workflow:test-writer` agent. Give it only:
   - the user's request and the grill answers;
   - the plan's test cases;
   - where the tests belong: existing test files, the public interfaces or seams, the test framework and its conventions;
   - the requirement or ticket IDs to put in test names.

   Do not give it the implementation diff or describe the code you intend to write.
2. **Run red.** When it returns, run the new tests yourself. Every one must fail, and fail for the right reason: an assertion or a missing export, not a syntax or setup error. Show the output.
3. **Fix test bugs, not expectations.** If a test fails for a setup reason, fix the setup or send it back. If you think an expectation is wrong, ask the user; never change it to match code.

   The Stop gate blocks a turn that ends with failing tests. When you must stop while the tests are red on purpose (to show them, or to ask the user about an expectation), pause the gate for that one turn first:

   ```
   touch "$(git rev-parse --absolute-git-dir)/tiered-workflow-pause"
   ```

   Do this only for that reason. The user is told the gate was paused, and it checks again on the next turn.
4. **Record.** Note in the plan which tests were written and the red result.
