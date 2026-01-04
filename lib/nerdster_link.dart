import 'dart:convert';

import 'package:nerdster/app.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

// TODO: Fix: type book, etc...
// CONSIDER: identity and PoV
String generateLink() {
  Map<String, String> params = <String, String>{};

  assert(fireChoice != FireChoice.fake, "Doesn't work with fake");
  // TODO: Leverage Prefs Settings identity/oneofus or pov
  if (fireChoice.name != FireChoice.prod.name) params['fire'] = fireChoice.name;

  // TODO: Leverage Prefs Settings identity/oneofus or pov
  if (b(signInState.pov)) {
    // TODO: pov instead
    params['identity'] = JsonEncoder().convert(Jsonish.find(signInState.pov!)!.json);
  }

  Prefs.setParams(params);
  Uri uri = Uri.base.replace(queryParameters: params);
  return uri.toString();
}
