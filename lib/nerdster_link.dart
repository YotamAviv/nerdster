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

  // TODO: Leverage Prefs Settings identity/oneofus
  params['fire'] = fireChoice.name;
  if (fireChoice != FireChoice.fake && b(signInState.center)) {
    params['oneofus'] = JsonEncoder().convert(Jsonish.find(signInState.center!)!.json);
  }
  
  Prefs.setParams(params);
  followNet.setParams(params);
  NetBar.setParams(params);

  String url = buildUrlWithQueryParams(Uri.base, params);
  return url;
}

// Kudos: https://gist.github.com/danielgomezrico/f0af61d40f37360e051e7bedde273541
String buildUrlWithQueryParams(Uri uri, Map<String, dynamic> queryParams) {
  final Uri fullUri = uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      ...queryParams,
    },
  );

  final String parsedUrl = fullUri.toString();

  if (parsedUrl[parsedUrl.length - 1] == '?') {
    return parsedUrl.substring(0, parsedUrl.length - 1);
  } else {
    return parsedUrl;
  }
}
