import 'package:flutter/material.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/util.dart';

bool bDev = fireChoice != FireChoice.prod;

class Prefs {
  static final ValueNotifier<bool> keyLabel = ValueNotifier(true);
  static final ValueNotifier<bool> showJson = ValueNotifier(bDev);
  static final ValueNotifier<bool> showStatements = ValueNotifier(bDev);
  static final ValueNotifier<bool> showKeys = ValueNotifier(bDev);
  static final ValueNotifier<bool> skipVerify = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> hideDismissed = ValueNotifier<bool>(true);

  static final ValueNotifier<bool> postSignin = ValueNotifier<bool>(false); // TODO: Eliminate
  static final ValueNotifier<bool> skipLgtm = ValueNotifier<bool>(false); // TODO: Persist
  static final ValueNotifier<bool> showDevMenu = ValueNotifier<bool>(bDev); // TODO: Eliminate, do differently

  static final ValueNotifier<int> oneofusNetDegrees = ValueNotifier<int>(5);
  static final ValueNotifier<int> oneofusNetPaths = ValueNotifier<int>(1);
  static final ValueNotifier<int> followNetDegrees = ValueNotifier<int>(5);
  static final ValueNotifier<int> followNetPaths = ValueNotifier<int>(1);

  static void init() {
    Map<String, String> params = Uri.base.queryParameters;
    if (b(params['keyLabel'])) keyLabel.value = bs(params['keyLabel']);
    if (b(params['showJson'])) showJson.value = bs(params['showJson']);
    if (b(params['showStatements'])) showStatements.value = bs(params['showStatements']);
    if (b(params['showKeys'])) showKeys.value = bs(params['showKeys']);
    if (b(params['skipVerify'])) skipVerify.value = bs(params['skipVerify']);
    if (b(params['hideDismissed'])) hideDismissed.value = bs(params['hideDismissed']);


    if (b(params['oneofusNetDegrees'])) oneofusNetDegrees.value = int.parse(params['oneofusNetDegrees']!);
    if (b(params['oneofusNetPaths'])) oneofusNetPaths.value = int.parse(params['oneofusNetPaths']!);
    if (b(params['followNetDegrees'])) followNetDegrees.value = int.parse(params['followNetDegrees']!);
    if (b(params['followNetPaths'])) followNetPaths.value = int.parse(params['followNetPaths']!);
  }

  static void setParams(Map<String, String> params) {
    // include when not the default value
    if (!keyLabel.value) params['keyLabel'] = keyLabel.value.toString();
    if (showJson.value) params['showJson'] = showJson.value.toString();
    if (showStatements.value) params['showStatements'] = showStatements.value.toString();
    if (showKeys.value) params['showKeys'] = showKeys.value.toString();
    if (!skipVerify.value) params['skipVerify'] = skipVerify.value.toString();
    if (!hideDismissed.value) params['hideDismissed'] = hideDismissed.value.toString();

    if (oneofusNetDegrees.value != 5) params['oneofusNetDegrees'] = oneofusNetDegrees.value.toString();
    if (oneofusNetPaths.value != 1) params['oneofusNetPaths'] = oneofusNetPaths.value.toString();
    if (followNetDegrees.value != 5) params['followNetDegrees'] = followNetDegrees.value.toString();
    if (followNetPaths.value != 1) params['followNetPaths'] = followNetPaths.value.toString();
  }

  Prefs._();
}
