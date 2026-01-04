import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

/// This is the test driver script for running integration tests.
///
/// It acts as a bridge between the host machine (where `flutter drive` runs)
/// and the target device/emulator (where the app and tests run).
///
/// Usage:
/// 1. Start chromedriver: `chromedriver --port=4444`
/// 2. Run the test:
/// ```bash
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/v2_basic_test.dart \
///   -d chrome
/// ```
///
/// See `docs/testing.md` for full details.
Future<void> main() => integrationDriver();
