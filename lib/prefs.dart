import 'package:flutter/material.dart';
import 'package:nerdster/main.dart';

// bool bDev = true;
bool bDev = fireChoice != FireChoice.prod;

class Prefs {
  static final ValueNotifier<bool> nice = ValueNotifier(true);
  static final ValueNotifier<bool> js = ValueNotifier(bDev);
  static final ValueNotifier<bool> showTrustStatements = ValueNotifier(bDev);
  static final ValueNotifier<bool> showEquivalentKeys = ValueNotifier(bDev);
  static final ValueNotifier<bool> showDevMenu = ValueNotifier<bool>(bDev);

  Prefs._();
}
