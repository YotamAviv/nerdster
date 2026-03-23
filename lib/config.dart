
class FirebaseConfig {
  /// Translates a canonical URL (e.g. from [HomedKey.fetchUrl]) to the actual
  /// endpoint for the current environment.
  ///
  /// In emulator mode, call [registerRedirect] during startup to map prod URLs
  /// to local equivalents. The trust pipeline calls [resolveUrl] on
  /// [HomedKey.fetchUrl]; the content pipeline uses [contentUrl].
  static final Map<String, String> _redirects = {};
  static void registerRedirect(String from, String to) => _redirects[from] = to;
  static String resolveUrl(String url) => _redirects[url] ?? url;

  /// The base URL for fetching Nerdster content statements.
  /// Always export.nerdster.org in production; emulator redirect applied if registered.
  static String get contentUrl => resolveUrl('https://export.nerdster.org');
}
