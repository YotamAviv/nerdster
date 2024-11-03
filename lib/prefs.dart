import 'package:flutter/material.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/util.dart';

// bool bDev = true;
bool bDev = fireChoice != FireChoice.prod;

class Prefs {
  static final ValueNotifier<bool> nice = ValueNotifier(true);
  static final ValueNotifier<bool> showStatements = ValueNotifier(bDev);
  static final ValueNotifier<bool> showKeys = ValueNotifier(bDev);
  static final ValueNotifier<bool> showDevMenu = ValueNotifier<bool>(bDev);
  static final ValueNotifier<bool> dontShowAgain = ValueNotifier<bool>(false);

  static void init() { // initWindowQueryParams
    Map<String, String> params = Uri.base.queryParameters;
    showStatements.value = bs(params['showStatements']);
    showKeys.value = bs(params['showKeys']);
  }

  static void setParams(Map<String, String> params) {
    if(showStatements.value) params['showStatements'] = true.toString();
    if(showKeys.value) params['showKeys'] = true.toString();
  }

  Prefs._();
}
