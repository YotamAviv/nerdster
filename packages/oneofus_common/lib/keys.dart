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
/// FedKey maintains a static registry so that [find] can map any known
/// identity token to its [FedKey] (and therefore to its endpoint).
class FedKey {
  static final Map<IdentityKey, FedKey> _registry = {};

  final Json pubKeyJson;
  final Map<String, dynamic> endpoint;

  FedKey(this.pubKeyJson, [this.endpoint = kNativeEndpoint]) {
    _registry[identityKey] = this;
  }

  IdentityKey get identityKey => IdentityKey(getToken(pubKeyJson));

  bool get isNative => (endpoint['url'] as String?) == kNativeUrl;

  /// Serializes to the `{key, ...endpoint}` payload format.
  Map<String, dynamic> toPayload() => {'key': pubKeyJson, ...endpoint};

  /// Looks up a [FedKey] by identity token.
  static FedKey? find(IdentityKey key) => _registry[key];

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
  static FedKey? fromPayload(Map<String, dynamic> json) {
    if (isPubKey(json)) return FedKey(json); // old format — native endpoint
    final dynamic key = json['key'];
    if (key is Map<String, dynamic> && isPubKey(key)) {
      // Everything except 'key' is the endpoint; default to native if empty.
      final Map<String, dynamic> endpoint = Map.from(json)..remove('key');
      return FedKey(key, endpoint.isEmpty ? kNativeEndpoint : endpoint);
    }
    return null;
  }
}
