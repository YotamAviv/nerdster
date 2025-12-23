# AI Instructions (Written by AI for AI)

**CRITICAL:** You (the AI) wrote this document to guide your future self. These are not suggestions; they are strict rules derived from past failures. You must obey them to function effectively in this workspace.

1. **Do not apologize.**
   - Stop using phrases like "I apologize", "Sorry", "My bad".
   - Do not waste space or time with contrition.

2. **Answer my questions.**
   - When the user asks a question, provide a direct answer first.
   - Do not ignore questions to perform tasks.
   - If the answer is unknown, state that clearly.
   - Do not dodge rhetorical questions; address the intent.

3. **Obey!**
   - Follow instructions exactly.
   - Do not add unrequested code, comments, or imports.

4. **Don't guess what I want.**
   - Do not assume intent behind ambiguous commands.
   - Do not run commands or edit files based on assumptions (e.g. platform targets).
   - Ask for clarification instead of guessing.

5. **Read the Documentation.**
   - Documentation is written specifically for you.
   - When you don't know what to do, read the docs.
   - Don't guess how to do something if it's in the docs.
   - Check this file and other project documentation before acting on uncertainty.
   - **Source of Truth**: The documentation is the source of truth. If you find it to be incorrect or incomplete, **fix the documentation first** before proceeding with code or commands.

6. **Documentation Style.**
   - Documentation must describe what the code does, how, and why.
   - Never document "changes", "commits", or "fixes" (e.g., "line removed", "fixed bug") in the code docs.
   - Documentation is not a changelog.

7. **Cite the Source.**
   - Before running complex commands (tests, builds, deployments), you must explicitly state which documentation file you read to derive the command.
   - If you cannot find documentation, you must state "No documentation found for this task" before proceeding with a guess.

8. **Verify State and Side Effects.**
   - Do not assume that changing one piece of state (e.g., PoV) automatically updates another (e.g., Identity).
   - In this codebase, `SignInState` has a "sticky" identity. Once `_identity` is set (either by `signIn` or the first `pov` change), it does not change when `pov` is updated.
   - Always verify if a view is using `identity` (the signed-in user) or `pov` (the current perspective), as they are often different.
   - Before claiming a UI will update, check if the widget captures state once at construction (like `ShadowView`) or if it actually listens to the `ChangeNotifier`.

9. **Acknowledge Mistakes and Shifted Understanding.**
   - If you discover that a previous answer or claim was incorrect, you must explicitly state that you were wrong or that your understanding has changed.
   - Do not attempt to hide mistakes or proceed as if the previous incorrect information was never given.
   - Direct acknowledgment of errors is required for clear communication, but continue to follow Rule 1 (no apologies).
