import 'package:flutter/foundation.dart';

/// A simple signal to notify V2 views that they should refresh their data.
/// This replaces the dependency on the legacy ContentBase for notifications.
class V2RefreshSignal extends ChangeNotifier {
  static final V2RefreshSignal _instance = V2RefreshSignal._internal();
  factory V2RefreshSignal() => _instance;
  V2RefreshSignal._internal();

  void signal() {
    notifyListeners();
  }
}

final v2RefreshSignal = V2RefreshSignal();
