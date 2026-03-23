import 'jsonish.dart';

/// The base URL for the native ONE-OF-US.NET trust statement export.
const String kNativeUrl = 'https://export.one-of-us.net';

/// The endpoint object for keys natively homed at ONE-OF-US.NET.
const Map<String, dynamic> kNativeEndpoint = {'url': kNativeUrl};

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

/// A public key paired with its service endpoint metadata.
///
/// [endpoint] is an arbitrary JSON object describing where this key's trust
/// statements are published. For ONE-OF-US.NET native keys it is
/// `{"url": "https://export.one-of-us.net"}`. Third-party keys carry whatever
/// their QR/invitation payload contained (minus the `"key"` field itself).
///
/// HomedKey maintains a static registry so that [find] can map any known
/// identity token to its [HomedKey] (and therefore to its [fetchUrl]).
class HomedKey {
  static final Map<String, HomedKey> _registry = {};

  final Json pubKeyJson;
  final Map<String, dynamic> endpoint;

  HomedKey(this.pubKeyJson, [this.endpoint = kNativeEndpoint]) {
    _registry[getToken(pubKeyJson)] = this;
  }

  String get token => getToken(pubKeyJson);

  /// The URL for fetching this key's trust statements, or null if the
  /// endpoint format is not recognized (e.g. a third-party key with no `url`).
  String? get fetchUrl => endpoint['url'] as String?;

  bool get isNative => fetchUrl == kNativeUrl;

  /// Serializes to the `{key, ...endpoint}` payload format.
  Map<String, dynamic> toPayload() => {'key': pubKeyJson, ...endpoint};

  /// Looks up a [HomedKey] by identity token.
  static HomedKey? find(String token) => _registry[token];

  /// Clears the registry. For testing only.
  static void clearRegistry() => _registry.clear();

  /// Parses from a QR code / invitation link / sign-in payload.
  ///
  /// Accepts both formats:
  ///   Old: bare key JSON  {"crv":...,"kty":"OKP","x":...}
  ///   New: {"key": {...}, "url": "...", ...}  (any extra fields preserved)
  ///
  /// Old format defaults to [kNativeEndpoint].
  /// Returns null if the payload is not a recognized format.
  static HomedKey? fromPayload(Map<String, dynamic> json) {
    if (isPubKey(json)) return HomedKey(json); // old format — native endpoint
    final dynamic key = json['key'];
    if (key is Map<String, dynamic> && isPubKey(key)) {
      // Everything except 'key' is the endpoint; default to native if empty.
      final Map<String, dynamic> endpoint = Map.from(json)..remove('key');
      return HomedKey(key, endpoint.isEmpty ? kNativeEndpoint : endpoint);
    }
    return null;
  }
}
