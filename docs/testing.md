# Nerdster Testing Strategy & Status

# My (the human) desire - DO NOT EDIT OR DELETE

- Clean and easy to understand, less mystery about what's being tested and what the AI generated scripts do
  - rename "basic test" to something closer to "cloud source test"

- Ability to test cloud function fetching on both Chrome and Android
This is currently covered by "basic test", and a prototype has made good progress in running it reliably
on Chrome, headless, with no leaked processes (against the Firebase emulator).

This same test should be run on Android (emulator), possibly with shared code, but the Android platform
should be able to leverage the flutter test infrastructure to run it on against the Firebase emulator.

- Keep the "ui test" but only run in on Anroid (emulator)

- Keep stuff that's worth keeping
  - manually run "corrupt egos" junk, helpers.
  - screenshot generation "test"

# Proposed Testing Plan: Filenames, Locations, and Scripts

### 1. Shared Logic
* **`lib/dev/cloud_source_verification.dart`**: (Renamed from `verification.dart`/`basicScenario`). Contains the core data pipeline logic. Shared by both Chrome and Android runners.

### 2. Chrome (Web) Runner
* **`lib/dev/widget_runner.dart`**: (Renamed from `headless_runner.dart`). The Flutter widget that mounts the testing runtime.
* **`bin/chrome_widget_runner.py`**: (Renamed from `run_headless_prototype.py`). Orchestrates `flutter run -d chrome`.
  * Accepts `-t <target>` argument (e.g. `python3 bin/chrome_widget_runner.py -t lib/dev/cloud_source_test.dart`) to target a specific test.
  * Accepts `--headless` argument to hide the browser.
  * Cleans up Chrome processes and exits cleanly.

### 3. Android Emulator Executables (`integration_test/`)
Executes natively on Android using `flutter test`.
* **`integration_test/ui_test.dart`**: The E2E visual test. Unchanged.
* **`integration_test/cloud_source_test.dart`**: (Renamed from `basic_test.dart`). Executes `cloud_source_verification.dart` using the mobile Firebase binaries.
* **`integration_test/magic_paste_test.dart`**: Tests the Dart `http/html` package fallback logic exclusively on Android.
* **`integration_test/screenshot_test.dart`**: Retained for App Store generation.
* **`integration_test/...`**: Legacy helpers and scripts retained for manual execution.

### 4. Master Orchestration
* **`bin/run_all_tests.sh`**: Stripped down to:
  1. `cd functions && npm test`
  2. `python3 bin/chrome_widget_runner.py --headless -t lib/dev/cloud_source_test.dart`
  3. If `flutter devices` detects an Emulator:
     - `flutter test integration_test/ui_test.dart`
     - `flutter test integration_test/cloud_source_test.dart`
     - `flutter test integration_test/magic_paste_test.dart`



## The Testing Landscape

Here is an overview of Nerdster's architecture components, their core responsibilities, and how they are currently tested across the repository (or the `oneofus_common` package).

| Component | Responsibility | Current Tests | Test Implementation/Strategy |
| :--- | :--- | :--- | :--- |
| **Common Domain** | Logic used identically by Both Nerdster (Web/App) and ONE-OF-US.NET (Phone App) (`packages/oneofus_common`) | **YES** | **Unit Tests** (`statement_test.dart`, `jsonish_test.dart`) run purely via standard Dart, mocking components efficiently. |
| **Logic / Trust** | Trust graph building, complex state refreshing, delegate logic (`test/logic/`) | **YES** | **Unit Tests** using standard `flutter test`. Real-time data synchronization layers rely safely on `FakeFirebaseFirestore` abstractions so they run fast. |
| **Serverless Backend** | Firebase Cloud Functions (IMDB logic, magic paste processing, metadata fetching) located in `functions/` | **YES** | **NPM Tests** (`npm test` mapped to `firebase-functions-test` locally). Evaluates the exact HTTP behavior and logic parsing correctly. |
| **UI Integration (E2E)** | Full flows: Booting the app, logging in as Lisa, tapping the screen, verifying Bart's feed update (`integration_test/`) | **SOMETIMES/FLAKY** | **Flutter Drive (Chrome)** via `bin/integration_test.sh`. Evaluated using `WidgetTester` against actual or emulated Firebase endpoints. |

---

## What's Problematic

1. **The Tooling Infrastructure (`flutter drive`):** 
Attempting to drive automated testing across the Web architecture using `flutter run` / `flutter drive` targeting Chrome (`-d chrome`) is fundamentally problematic. The testing framework requires constant WebDriver orchestration over WebSockets. It consistently drops connection packets, fails to close the active Chrome browser, leaves zombie renderer processes in your OS, and hangs simple shell scripts indefinitely.

2. **The Fragility of Traditional End-to-End Tests:**
It conceptually makes sense to write tests that mimic a real user: *Launch as Lisa -> Click the "Rate" button -> Select 5 on slider -> Wait for Bart's screen to update.* 
However, in practically any complex Flutter application, these tests are intrinsically flaky. They depend intensely on precise DOM/Widget rendering timing, network latency to the emulators, and UI transition animations yielding control correctly. Consequently, they run slowly and often fail with false positives, making them not worth the pain for developers to maintain.

## What We Have & What We Are Missing

**What we have:** 
We have exceptional internal coverage over the data pipelines. We effectively test our backend functions, our core package dependencies, and our intricate Trust Algorithm via `FakeFirebaseFirestore` mocks locally.

**What we are missing:**
A defined strategy for how to write "End-to-End" scenarios without the overhead of UI clicking. 

**Proposed Direction: "Headless" Integration Scripts**

The true value of a "Lisa rates something, Bart sees it" test isn't proving that the `ElevatedButton` works. It's proving that when Lisa executes a Firestore write operation, Bart's live `FeedController` graph recalculates and streams the new layout globally! 

Instead of using `flutter drive` and `WidgetTester` to simulate the *mouse clicks*, we can write pure data integration pipelines (like `basicScenario`) that launch instances of our core Controllers, orchestrate the writes using Emulators, and `expect()` that Bart's state updates globally. 

This guarantees cross-component testing (E2E), takes only a fraction of a second to run natively without `flutter drive`, and is never flaky due to missing UI animations.
