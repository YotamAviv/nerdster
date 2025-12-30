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
cd functions
npm test
```

This runs all tests in the `functions/test/` directory.

## Integration Tests

Integration tests run in a browser environment and interact with local Firebase Emulators.

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

# Simpsons Relate Demo

To run the Simpsons Relate/Equate demo (V2):

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

