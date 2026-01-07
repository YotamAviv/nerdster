read AI.md


read AI.md
DO NOT EDIT FILES!
DO NOT RUN COMMANDS!
ANSWER MY QUESTIONS!


read AI.md
read the testing docs
run all tests, unti and integration tests included.


run git status
run git diff on every change
read those changes
Let me know if you notice anything that might be problematic.
If not, suggest a commit message based only on the GIT diffs, not based on your memory
Output ONLY the commit message in a code block, with no conversational summary.

Output ONLY the commit message here below:

```text
Metadata service: Structured sources, optimization, and Smart Fetch expansion

- API Update: fetchImages now returns {url, source} objects for better attribution.
- Optimization: Added maxImages param to executeFetchImages. Client defaults to 1 for speed; Debug Server defaults to 100.
- Core Logic: Removed smartTypes whitelist; now attempts Smart Fetch (Wikipedia/OpenLibrary) for all titled content if limit not reached.
- YouTube: fetchFromYouTube is now async and validates maxresdefault.jpg availability via HEAD request.
- Client: Updated MetadataService to parse the new object structure.
- Docs & Tests: Updated metadata_service.md and fixed backend tests to align with async/object changes.
- Misc: Updated TODO in model.dart.
```