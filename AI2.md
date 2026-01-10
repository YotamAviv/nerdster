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
Copy/paste from our conversation never works for me for this, and so:
Output ONLY the commit message here in this file right here:

Refactor personal stance handling to use global overlay maps

- Replaced SubjectGroup.myDelegateStatements with global maps in ContentAggregation: myLiteralStatements and myCanonicalDisses.
- Implemented literal token lookups in RateDialog, RelateDialog, and NodeDetails to ensure accurate hydration of personal history.
- Updated dismissal logic to use myCanonicalDisses for cross-alias filtering in feed_controller.dart and content_card.dart.
- Removed UI guard in NodeDetails preventing visibility of personal follows for subjects excluded from the network aggregation.
- Updated unit and integration tests to align with the new personal stance architecture.
- Added regression test for follow visibility of out-of-network identities.
