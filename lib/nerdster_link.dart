import 'dart:convert';

import 'package:nerdster/app.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

String generateLink() {
  Map<String, String> params = <String, String>{};

  assert(fireChoice != FireChoice.fake, "Doesn't work with fake");
  if (fireChoice.name != FireChoice.prod.name) params['fire'] = fireChoice.name;

  if (b(signInState.pov)) {
    // TODO: pov instead
    params['identity'] = JsonEncoder().convert(Jsonish.find(signInState.pov)!.json);
  }

  Prefs.setParams(params);
  Uri uri = Uri.base.replace(queryParameters: params);
  return uri.toString();
}
