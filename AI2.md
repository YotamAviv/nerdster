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
Append the commit message to the end of this file:

Enforce tokenization for all follow statements

- Update ContentStatement.make to always tokenize follow verbs.
- Update documentation in content_statement_semantics.md to reflect that follow subjects are now identity tokens.
- Refactor lib/v2/node_details.dart and demo_key.dart to pass identity tokens directly for follow statements.
- Improve robustness of rate_when_not_in_network.dart test with type-safe lookups and explicit exception throwing for missing subjects.
- Update debug_token_test.dart to reflect the new tokenization requirement for follow statements.


