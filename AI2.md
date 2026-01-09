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

feat(content): standardise subject tokenization rules and docs

- Implement verb-specific tokenization logic in `ContentStatement.make` following 4 strict rules:
  1. Rate: Tokenize statements, dismissals, or censors.
  2. Relations: Never tokenize (always preserved full metadata).
  3. Follow: Tokenize strictly for blocks (weights = -1).
  4. Clear: Always tokenize.
- Sync `content_statement_semantics.md` to remove outdated "Suppression" logic and resolve contradictions between Rule 1 and Rule 2.
- Update `debug_token_test.dart` to verify that relations between statements preserve full JSON metadata.
- Clean up unused `subjectCanonical` from `StatementTile` to encourage lateral literal comparisons for UI symmetry.
