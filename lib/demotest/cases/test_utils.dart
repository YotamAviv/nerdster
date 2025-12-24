/// **Architectural Note:**
/// This file (and others in this directory) lives in `lib/` so it can be imported by both:
/// 1. Unit tests (in `test/`)
/// 2. Integration tests (in `integration_test/`)
///
/// It avoids importing `package:test` (which contains `expect`) because
/// `package:test` should generally be a `dev_dependency`. Importing it here
/// would force it to be a regular `dependency`, bloating the production app.
///
/// Instead, we use the [check] helper below to throw standard Exceptions.
library;

/// Helper to enforce conditions even in release mode.
/// 
/// Standard Dart `assert()` is removed in release builds. Since we might run
/// integration tests in release mode (or "profile" mode) to test performance,
/// we need a check that always executes.
void check(bool condition, String reason) {
  if (!condition) {
    throw Exception('Verification Failed: $reason');
  }
}
