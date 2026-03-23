import 'dart:convert';

class FirebaseConfig {
  static final Map<String, String> _urls = {};

  static void registerUrl(String domain, String url) {
    _urls[domain] = url;
  }

  static String? getUrl(String domain) => _urls[domain];

  /// Translates a canonical URL (e.g. from [HomedKey.fetchUrl]) to the actual
  /// endpoint for the current environment.
  ///
  /// In emulator mode, call [registerRedirect] during startup to map prod URLs
  /// to local equivalents. Phase 2 federation code should call [resolveUrl]
  /// instead of using [HomedKey.fetchUrl] directly.
  static final Map<String, String> _redirects = {};
  static void registerRedirect(String from, String to) => _redirects[from] = to;
  static String resolveUrl(String url) => _redirects[url] ?? url;

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
