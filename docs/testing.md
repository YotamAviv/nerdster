# Testing Guide

## Unit Tests

Run unit tests using the standard Flutter command:

```bash
flutter test
```

## JavaScript Tests

The JavaScript implementation of the "jsonish" tokenization logic is tested against exported samples to ensure parity with the Dart implementation.

Run the test using Node.js:

```bash
node js/jsonish.js
```

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

Run the integration tests using `flutter drive`.

**V2 Basic Test:**

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/v2_basic_test.dart \
  -d chrome
```

### Troubleshooting

*   **"Unable to start a WebDriver session"**: Ensure `chromedriver` is running on port 4444.
*   **"Failed to connect to the VM Service"**: Ensure you are using `-d chrome` (or `-d web-server` if configured correctly) and that the port is not blocked.
