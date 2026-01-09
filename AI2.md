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

feat(v2): implement Pure PoV feed and literal-subject dense map architecture

- Refactor aggregation to decouple shared truth (SubjectGroup) from literal identity (SubjectAggregation).
- Transition to a "dense map" where every literal token is represented in the aggregation, supporting precise selection and rating.
- Enforce "Pure PoV" by isolating the viewer's own ratings into an independent `myStatements` overlay, preventing pollution of trust-network stats.
- Update UI (ContentView/Card/Tile) to utilize literal tokens for marking and selection via local ValueNotifiers.
- Enhance aggregation efficiency with dual-transformer signature generation and "Merge, don't sort" optimization.
- Standardize V2Labeler as a required pipeline dependency for consistent title resolution across equivalent subjects.
- Update and verify entire V2 test suite (83 tests) against new architectural constraints.