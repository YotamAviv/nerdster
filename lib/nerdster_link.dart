import 'dart:convert';

import 'package:nerdster/main.dart';
import 'package:nerdster/net/net_bar.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

// DEFER: add other network settings: degrees? (statements?, numOneofus?, numFollow?, )
String generateLink() {
  Map<String, String> params = <String, String>{};

  assert(fireChoice != FireChoice.fake, "Doesn't work with fake");
  params['fire'] = fireChoice.name;

  // TODO: Leverage Prefs Settings identity/oneofus or pov
  if (b(signInState.pov)) {
    // TODO: pov instead
    params['identity'] = JsonEncoder().convert(Jsonish.find(signInState.pov!)!.json);
  }

  Prefs.setParams(params);
  NetBar.setParams(params);
  Uri uri = Uri.base.replace(queryParameters: params);
  return uri.toString();
}
