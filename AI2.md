read AI.md


read AI.md
DO NOT EDIT FILES!
DO NOT RUN COMMANDS!
ANSWER MY QUESTIONS!


read AI.md
read the testing docs
run all tests, unti and integration tests included.


fix: Sort statements in ContentLogic and refactor UI to use ContentKey

- Fixes 'Statements are not in descending time order' error by sorting statement lists in `reduceContentAggregation`.
- Simplifies identity resolution in `content_logic.dart` (assumes trusted signer).
- Fixes `RenderFlex overflowed` in `credentials_display.dart` by wrapping children in `Expanded`.
- Refactors `ContentCard`, `ContentView`, and `StatementTile` to use `ContentKey` instead of String for tagged subjects.
