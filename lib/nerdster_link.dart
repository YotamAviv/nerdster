import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/singletons.dart';

String generateLink() {
  Map<String, String> params = <String, String>{};

  assert(fireChoice != FireChoice.fake, "Doesn't work with fake");
  if (fireChoice.name != FireChoice.prod.name) params['fire'] = fireChoice.name;

  params['identity'] = JsonEncoder().convert(Jsonish.find(signInState.pov)!.json);

  Prefs.setParams(params);
  // On web: Uri.base preserves the current host (localhost for emulator, nerdster.org for prod).
  // On native (iOS/Android): Uri.base is file:/// — use nerdster.org explicitly.
  final Uri baseUri = kIsWeb ? Uri.base : Uri.parse('https://nerdster.org/app');
  Uri uri = baseUri.replace(queryParameters: params);
  return uri.toString();
}
