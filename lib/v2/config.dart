import 'dart:convert';

class V2Config {
  static final Map<String, String> _urls = {};

  static void registerUrl(String domain, String url) {
    _urls[domain] = url;
  }

  static String? getUrl(String domain) => _urls[domain];

  static Uri makeSimpleUri(String domain, dynamic spec, {String? revokeAt}) {
    final String? baseUrl = getUrl(domain);
    if (baseUrl == null) {
      return Uri.parse('about:blank');
    }
    
    final uri = Uri.parse(baseUrl);
    final params = <String, String>{'spec': jsonEncode(spec)};
    if (revokeAt != null) {
      params['revokeAt'] = revokeAt;
    }
    
    final newParams = Map<String, String>.from(uri.queryParameters)..addAll(params);
    return uri.replace(queryParameters: newParams);
  }
}
