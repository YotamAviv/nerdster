import 'dart:async';

/// No‑op version for non‑web platforms and tests.
StreamSubscription<void> bindPopState(void Function() onBack) {
  return StreamController<void>().stream.listen((_) {});
}
