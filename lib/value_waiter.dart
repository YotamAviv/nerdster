import 'dart:async';

import 'package:flutter/material.dart';

// Kudos: https://gist.github.com/dumazy/ff362af06e1b2824f2931f721bc6434f
class ValueWaiter {
  final ValueNotifier _notifier;
  final dynamic value;
  final Completer<void> _completer = Completer<void>();

  ValueWaiter(this._notifier, this.value) {
    _notifier.addListener(_listen);
  }

  void _listen() {
    if (_notifier.value == value) {
      _notifier.removeListener(_listen);
      _completer.complete();
    }
  }

  Future<void> untilReady() async {
    if (_notifier.value == value) {
      return;
    } else {
      await _completer.future;
      // NOTE: This does fire: 
      //   assert(_notifier.value == value);
    }
  }
}
