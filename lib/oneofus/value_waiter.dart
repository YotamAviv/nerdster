import 'dart:async';

import 'package:flutter/material.dart';

// Kudos: https://gist.github.com/dumazy/ff362af06e1b2824f2931f721bc6434f
class ValueWaiter<T> {
  final ValueNotifier<T> _notifier;
  final T value;
  final Completer<void> _completer = Completer<void>();

  ValueWaiter(this._notifier, this.value) {
    if (_notifier.value == value) {
      _completer.complete();
    } else {
      _notifier.addListener(_listen);
    }
  }

  void _listen() {
    if (_notifier.value == value) {
      _notifier.removeListener(_listen);
      if (!_completer.isCompleted) {
        _completer.complete();
      }
    }
  }

  Future<void> untilReady() => _completer.future;
}
