import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/util.dart';

bool devDefault = fireChoice != FireChoice.prod;
bool bNerd = devDefault;
// bool bNerd = true;

class Prefs {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Settings
  static final ValueNotifier<bool> skipLgtm = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> censor = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> hideDismissed = ValueNotifier<bool>(true);
  static final ValueNotifier<int> oneofusNetDegrees = ValueNotifier<int>(5);
  static final ValueNotifier<int> oneofusNetPaths = ValueNotifier<int>(1);
  static final ValueNotifier<int> followNetDegrees = ValueNotifier<int>(5);
  static final ValueNotifier<int> followNetPaths = ValueNotifier<int>(1);
  static final ValueNotifier<bool> keyLabel =
      ValueNotifier(true); // historic, deprecated, but used by tests
  static final ValueNotifier<bool> skipVerify = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> showJson = ValueNotifier(bNerd);
  static final ValueNotifier<bool> showKeys = ValueNotifier(bNerd);
  static final ValueNotifier<bool> showStatements = ValueNotifier(bNerd);
  static final ValueNotifier<bool> showStuff = ValueNotifier<bool>(bNerd);

  // DEV:
  static final ValueNotifier<bool> dev = ValueNotifier<bool>(devDefault || bNerd);
  // DEFER: These are not all compatible with each other, no worries..
  static final ValueNotifier<bool> cloudFunctionsFetch = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> batchFetch = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> streamBatchFetch = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> slowFetch = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> fetchRecent = ValueNotifier<bool>(false);

  static Future<void> init() async {
    Map<String, String> params = Uri.base.queryParameters;
    if (b(params['keyLabel'])) keyLabel.value = bs(params['keyLabel']);
    if (b(params['showJson'])) showJson.value = bs(params['showJson']);
    if (b(params['showStatements'])) showStatements.value = bs(params['showStatements']);
    if (b(params['showKeys'])) showKeys.value = bs(params['showKeys']);
    if (b(params['censor'])) censor.value = bs(params['censor']);
    if (b(params['hideDismissed'])) hideDismissed.value = bs(params['hideDismissed']);

    if (b(params['oneofusNetDegrees'])) {
      oneofusNetDegrees.value = int.parse(params['oneofusNetDegrees']!);
    }
    if (b(params['oneofusNetPaths'])) oneofusNetPaths.value = int.parse(params['oneofusNetPaths']!);
    if (b(params['followNetDegrees'])) {
      followNetDegrees.value = int.parse(params['followNetDegrees']!);
    }
    if (b(params['followNetPaths'])) followNetPaths.value = int.parse(params['followNetPaths']!);

    try {
      String? skipLgtmS = await _storage.read(key: 'skipLgtm');
      if (b(skipLgtmS)) skipLgtm.value = bool.parse(skipLgtmS!);
    } catch (e) {
      print(e);
    }

    Prefs.showStuff.addListener(() {
      Prefs.showJson.value = showStuff.value;
      Prefs.showKeys.value = showStuff.value;
      Prefs.showStatements.value = showStuff.value;
    });

    Prefs.skipLgtm.addListener(listener);
  }

  static void setParams(Map<String, String> params) {
    // include when not the default value
    if (!keyLabel.value) params['keyLabel'] = keyLabel.value.toString();
    if (showJson.value) params['showJson'] = showJson.value.toString();
    if (showStatements.value) params['showStatements'] = showStatements.value.toString();
    if (showKeys.value) params['showKeys'] = showKeys.value.toString();
    if (!skipVerify.value) params['skipVerify'] = skipVerify.value.toString();
    if (!censor.value) params['censor'] = censor.value.toString();
    if (!hideDismissed.value) params['hideDismissed'] = hideDismissed.value.toString();

    if (oneofusNetDegrees.value != 5)
      params['oneofusNetDegrees'] = oneofusNetDegrees.value.toString();
    if (oneofusNetPaths.value != 1) params['oneofusNetPaths'] = oneofusNetPaths.value.toString();
    if (followNetDegrees.value != 5) params['followNetDegrees'] = followNetDegrees.value.toString();
    if (followNetPaths.value != 1) params['followNetPaths'] = followNetPaths.value.toString();
  }

  static Future<void> listener() async {
    await _storage.write(key: 'skipLgtm', value: Prefs.skipLgtm.value.toString());
  }

  Prefs._();
}
