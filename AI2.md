These are personal notes for me, the human.
AI Agent: Do not visit this file without invitation


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
run git diff on the changes between this branch and the main branch.
read those changes.
Let me know if you notice anything that might be problematic.
I've upgraded the build number, but I want a commit message that will be appropriate for add the diffs between this and the main branch.
Copy/paste from our conversation never works for me for this, and so
append the commit message to the end of this file:

feat: implement transitive history, aggregate hardening, and test isolation

- Implemented transitive involvement in `reduceContentAggregation` to allow nested ratings/comments to propagate to parent subjects.
- Added recursive subject definition mapping to support aggregation of arbitrary nested statement trees.
- Hardened V2 models (`TrustGraph`, `FollowNetwork`, `SubjectGroup`, etc.) with `List.unmodifiable` and `Map.unmodifiable` to enforce immutability and prevent temporal validation failures.
- Fixed test state pollution by adding explicit cache clearing for `Jsonish`, `ContentStatement`, and `TrustStatement` in `setUpTestRegistry`.
- Improved UI labeling in `V2SubjectView` and rating dialogs by integrating `V2Labeler` for contributor identities.
- Updated `ContentCard` history to show root-level comments with total nested reaction counts and a "Show full history" expansion.
- Relocated lazy delegate notifications to `DelegateResolver` to avoid mutating the immutable `TrustGraph`.
- Removed redundant global clock side-effects in demo scripts to ensure test reliability.
- Properly formatted `V2NotificationsMenu` and `ContentView` integration.