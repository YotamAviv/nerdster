# Nerdster V2: Reactive Architecture

This directory contains the "Clean Rewrite" of the Nerdster core logic.

## Principles
1.  **Pure Functions:** Logic is separated from I/O.
2.  **Immutable State:** State is passed through reducers, not held in singletons.
3.  **Pipelines:** Data flows from Source -> Transform -> Sink.

## Structure
*   `logic/`: Pure business logic (Trust, Content, Censorship).
*   `model/`: Immutable data structures.
*   `io/`: Fetching and side-effects (Cloud Functions, Firestore).
