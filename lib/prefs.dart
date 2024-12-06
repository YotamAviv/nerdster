import 'package:flutter/material.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/util.dart';

// bool bDev = true;
bool bDev = fireChoice != FireChoice.prod;

class Prefs {
  static final ValueNotifier<bool> nice = ValueNotifier(true);
  static final ValueNotifier<bool> showJson = ValueNotifier(bDev);
  static final ValueNotifier<bool> showStatements = ValueNotifier(bDev);
  static final ValueNotifier<bool> showKeys = ValueNotifier(bDev);
  static final ValueNotifier<bool> showDevMenu = ValueNotifier<bool>(bDev);
  static final ValueNotifier<bool> skipLgtm = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> skipVerify = ValueNotifier<bool>(true);

  static void init() { // initWindowQueryParams
    Map<String, String> params = Uri.base.queryParameters;
    showJson.value = bs(params['showJson']);
    showStatements.value = bs(params['showStatements']);
    showKeys.value = bs(params['showKeys']);
    if (b(params['skipVerify'])) {
      skipVerify.value = bs(params['skipVerify']);
    }
  }

  static void setParams(Map<String, String> params) {
    if(showJson.value) params['showJson'] = true.toString();
    if(showStatements.value) params['showStatements'] = true.toString();
    if(showKeys.value) params['showKeys'] = true.toString();
    params['skipVerify'] = skipVerify.value.toString();
  }

  Prefs._();
}
