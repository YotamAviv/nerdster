# Testing Guide

## Unit Tests

Run unit tests using the standard Flutter command:

```bash
flutter test
```

## Backend (JavaScript) Tests

The backend logic (Cloud Functions) is tested using the built-in Node.js test runner. This includes:
- **Jsonish Parity**: Ensuring the JavaScript implementation of tokenization and ordering matches the Dart implementation.
- **Metadata Fetchers**: Verifying title and image extraction from external sources.

### Running Backend Tests

Navigate to the `functions` directory and run:

```bash
(cd functions && npm test)
```

**Note:** Use a subshell `(cd ...)` or chain commands to ensure you return to the project root if running subsequent commands.

This runs all tests in the `functions/test/` directory.

## Integration Tests

Integration tests run in a browser environment and interact with local Firebase Emulators.

**AI Note:** Do not kill existing `chromedriver` or `firebase` processes without asking.

### Prerequisites

1.  **Firebase Emulators**: You must run emulators for both projects (Nerdster and One-of-us-net) simultaneously. Open two terminal tabs and run:

    **Terminal 1 (Nerdster):**
    ```bash
    firebase --project=nerdster emulators:start
    ```

    **Terminal 2 (One-of-us-net):**
    ```bash
    firebase --project=one-of-us-net --config=oneofus.firebase.json emulators:start
    ```

2.  **ChromeDriver**: You must have `chromedriver` installed and running on port 4444.
    *   **Install** (Linux):
        ```bash
        sudo apt install chromium-chromedriver
        ```
    *   **Run**:
        ```bash
        chromedriver --port=4444
        ```

### Running the Tests

Integration tests require Chrome. Do not use `-d linux`.

Run using the helper script or `flutter drive`:

**Using the helper script:**

```bash
./bin/integration_test.sh
```

**Using flutter drive directly:**

```bash
# Basic Logic Tests
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/v2_basic_test.dart \
  -d chrome

# UI Tests
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/v2_ui_test.dart \
  -d chrome

## Corruption Testing

[Aviv, the human]: I tested corruption detection manually and it worked.
TODO: Automate this after V2 

Corruption testing involves two parts: generating corrupted data and verifying that the system detects it.

### 1. Generate Corruption Data (Integration Test)

This script runs in the browser (Chrome) to generate keys and sign statements, then intentionally corrupts them (e.g., invalid signature, broken chain) and saves the tokens to `integration_test/corruption_data.json`.

**Run with:**
```bash
./bin/generate_corruption_data.sh
```
*Or manually:*
```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/generate_corruption_data.dart \
  -d chrome
```

### 2. Verify Detection (Integration Test)

The verification test reads the generated tokens and asserts that the V2 pipeline detects the corruption (via `TrustNotification`).

**Run with:**
```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/corruption_test.dart \
  -d chrome
```

## Utilities & Demos

### Simpsons Relate Demo (Data Seeding)

This script runs as an integration test but functions as a utility to populate the local Firebase Emulator with the "Simpsons" dataset (identities, trust, content). It outputs credentials to the console for manual login. It does not perform assertions.

```bash
./bin/run_simpsons_relate_demo.sh
```
```

### Troubleshooting

*   **"Unable to start a WebDriver session"**: Ensure `chromedriver` is running on port 4444.
*   **"Failed to connect to the VM Service"**: Ensure you are using `-d chrome` (or `-d web-server` if configured correctly) and that the port is not blocked.

## TODO: Image Relevance Regression Testing

We need a way to ensure that the images fetched for subjects (books, movies, etc.) remain relevant and high-quality.
- **Goal**: Prevent "degraded" or irrelevant images from appearing in the feed.
- **Proposed Strategy**:
    1.  **Golden Set**: Maintain a list of subjects with known "good" image URLs.
    2.  **Automated Check**: A test that runs the `fetchImages` cloud function for these subjects and verifies that the returned images are still in the golden set or meet certain criteria (e.g., resolution, source domain).
    3.  **AI-Assisted Review**: Periodically use a vision model to score the relevance of fetched images against the subject's title and tags.

