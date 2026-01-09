read AI.md


read AI.md
DO NOT EDIT FILES!
DO NOT RUN COMMANDS!
ANSWER MY QUESTIONS!


read AI.md
read the testing docs
run all tests, unti and integration tests included.


read AI.md
run git status
run git diff on every change
read those changes
Let me know if you notice anything that might be problematic.
If not, suggest a commit message based only on the GIT diffs, not based on your memory
Output ONLY the commit message here in this file right here:

Refactor test utilities and cleanup content logic

- Move `createTestSubject` to shared `lib/demotest/test_util.dart`.
- Delete `lib/demotest/demo_util.dart` and abandoned corruption tests.
- Add `equivalenceBug` demo case to reproduce issue.
- Refactor `reduceContentAggregation` in `content_logic.dart` for better subject lookup.
- Simplify `ContentStatement.make` logic.
- Register `equivalenceBug` and simplify `makeRelate` in `DemoKey`.
- Update docs with TODOs.
