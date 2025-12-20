class V2Config {
  static final Map<String, String> _urls = {};

  static void registerUrl(String domain, String url) {
    _urls[domain] = url;
  }

  static String? getUrl(String domain) => _urls[domain];
}
