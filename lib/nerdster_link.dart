// Use language features to build the url
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:nerdster/singletons.dart';

// TODO: Add follow settings (and maybe other network settings)
String generateLink() {
  Map<String, String> params = <String, String>{};
  params['oneofus'] = SignInState().center;
  params['fire'] = fireChoice.name;
  params['sort'] = contentBase.sort.name;
  params['type'] = contentBase.type.name;
  params['timeframe'] = contentBase.timeframe.name;
  params['censor'] = contentBase.censor.toString();
  if (b(followNet.fcontext)) {
    params['follow'] = followNet.fcontext!;
  }
  String url = buildUrlWithQueryParams(Uri.base, params);
  return url;
}

// Kudos: https://gist.github.com/danielgomezrico/f0af61d40f37360e051e7bedde273541
String buildUrlWithQueryParams(Uri uri, Map<String, dynamic> queryParams) {
  final fullUri = uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      ...queryParams,
    },
  );

  final parsedUrl = fullUri.toString();

  if (parsedUrl[parsedUrl.length - 1] == '?') {
    return parsedUrl.substring(0, parsedUrl.length - 1);
  } else {
    return parsedUrl;
  }
}
