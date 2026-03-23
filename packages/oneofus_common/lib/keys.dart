import 'jsonish.dart';

/// The native home for keys on the ONE-OF-US.NET network.
const String kNativeHome = 'export.one-of-us.net';

/// All known home values that map to the native network.
const Set<String> kKnownHomes = {'one-of-us.net', kNativeHome};

/// type-safe wrappers
extension type IdentityKey(String value) {}
extension type DelegateKey(String value) {}

// The token of a subject in a ContentStatement.
// These are the things that
// - content equivalence is defined over.
// - are associated with ratings, disses, etc..
extension type ContentKey(String value) {}

/// Returns true if [json] is a valid JWK Ed25519 public key.
bool isPubKey(Map<String, dynamic> json) =>
    json.containsKey('x') && json.containsKey('crv') && json['kty'] == 'OKP';

/// A public key paired with its home identifier.
///
/// Home is the hostname of the organization's trust statement export endpoint.
/// For ONE-OF-US.NET native keys, home is [kNativeHome].
///
/// HomedKey maintains a static registry so that [find] can map any known
/// identity token to its [HomedKey] (and therefore to its [fetchUrl]).
class HomedKey {
  static final Map<String, HomedKey> _registry = {};

  final Json pubKeyJson;
  final String home;

  HomedKey(this.pubKeyJson, [this.home = kNativeHome]) {
    _registry[getToken(pubKeyJson)] = this;
  }

  String get token => getToken(pubKeyJson);

  /// The base URL for fetching this key's trust statements.
  String get fetchUrl => 'https://$home';

  bool get isNative => kKnownHomes.contains(home);

  /// Serializes to the {key, home} payload format.
  Map<String, dynamic> toPayload() => {'key': pubKeyJson, 'home': home};

  /// Looks up a [HomedKey] by identity token.
  static HomedKey? find(String token) => _registry[token];

  /// Clears the registry. For testing only.
  static void clearRegistry() => _registry.clear();

  /// Parses from a QR code / invitation link / sign-in payload.
  ///
  /// Accepts both formats:
  ///   Old: bare key JSON  {"crv":...,"kty":"OKP","x":...}
  ///   New: {"key": {...}, "home": "..."}
  ///
  /// Missing [home] defaults to [kNativeHome]. Unknown homes throw [UnsupportedError].
  /// Returns null if the payload is not a recognized format.
  static HomedKey? fromPayload(Map<String, dynamic> json) {
    if (isPubKey(json)) return HomedKey(json); // old format — native home
    final dynamic key = json['key'];
    if (key is Map<String, dynamic> && isPubKey(key)) {
      final String home = (json['home'] as String?) ?? kNativeHome;
      if (!kKnownHomes.contains(home)) {
        throw UnsupportedError(
          'Key Federation not yet supported (home: $home). '
          'Update your app to vouch for keys from other organizations.',
        );
      }
      return HomedKey(key, home);
    }
    return null;
  }
}
