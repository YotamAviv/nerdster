import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

/// Statement signing and verification are handled here.
/// Getting the map from this object, and then signing that, and then putting the
/// signature back in the map seems tedious and error prone.
///
/// These are all related:
/// - signature (crypto private key signature of everything but the signature itself)
/// - token (hash of pretty printed everything (including the signature))
///   - the key in our caches,
///   - key used in Firestore
///   - hash reference to censored subjects (so that we don't show the censored subject)
/// - ordered Map<String, dynamic>
///
/// Bonuses of this class give us:
/// - hash value for caches, Maps (SHA1 of the JSON pretty-printed string)
/// - identical objects when reading the same JSON (Firebase likes to reorder the fields)
/// - generate pretty-printed JSON in our preferred order of map keys
///
/// CONSIDER: We use either Json or a token all over the place (subject, other, oneofusKey, ..).
/// Make Jsonish be either Json or a string token.

const JsonEncoder encoder = JsonEncoder.withIndent('  ');
typedef Json = Map<String, dynamic>;

abstract class StatementSigner {
  Future<String> sign(Json json, String string);
}

abstract class StatementVerifier {
  Future<bool> verify(Json json, String string, signature);
}

// This is here in Jsonish because I wanted the oneofus dir not to depend on Content
// stuff, not super elegant.
enum TrustVerb {
  trust('trust', 'trusted'),
  block('block', 'blocked'),
  replace('replace', 'replaced'), // requires 'revokeAt'

  delegate('delegate', 'delegated'), // allows 'revokeAt'

  clear('clear', 'cleared');

  const TrustVerb(this.label, this.pastTense);
  final String label;
  final String pastTense;
}

enum ContentVerb {
  // apply to 'subject'
  rate('rate', 'rated'), // (comment), recommend, dismiss, ..

  // apply to 'subject', 'otherSubject'.
  relate('relate', 'related'),
  dontRelate('dontRelate', 'un-related'),
  equate('equate', 'equated'),
  dontEquate('dontEquate', 'un-equated'),

  follow('follow', 'followed'),

  clear('clear', 'cleared');

  const ContentVerb(this.label, this.pastTense);
  final String label;
  final String pastTense;
}

/// This is used for lots of stuff, which makes it seem kludgey and problemnatic.
/// - trust statements
/// - content statements
/// - subjects
/// - keys
class Jsonish {
  static final List<String> keysInOrder = [
    'statement',
    'time',
    'I',
    ...TrustVerb.values.map((e) => e.label),
    ...ContentVerb.values.map((e) => e.label),
    'with',
    'other',
    'moniker',
    'revokeAt',
    'domain',
    'tags', // gone but may exist in old statements
    'recommend', // legacy.. should be called "like", (true: like, false: dislike)
    'dismiss',
    'censor',
    'stars', // gone but may exist in old statements

    'comment',

    'contentType', // for subjects like book, movie..

    'previous',
    'signature',
  ];
  static const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  static final Map<String, int> key2order =
      Map.unmodifiable({for (var e in keysInOrder) e: keysInOrder.indexOf(e)});

  static int compareKeys(String key1, String key2) {
    // Keys we know have an order.
    // Keys we don't know are ordered alphabetically below keys we know except signature.
    int? key1i = key2order[key1];
    int? key2i = key2order[key2];
    if (key1i != null && key2i != null) {
      return key1i - key2i;
    } else if (key1i == null && key2i == null) {
      return key1.compareTo(key2);
    } else if (key1i != null) {
      return -1;
    } else {
      return 1;
    }
  }

  // The cache of all Jsonish objects
  static final Map<String, Jsonish> _cache = <String, Jsonish>{};
  static Jsonish? find(String token) => _cache[token];
  static void wipeCache() => _cache.clear(); // probably for testing

  final Json _json; // (unmodifiable LinkedHashMap)
  final String _token;

  /// Return either a newly constructed Jsonish or one from the cache
  /// (all equal intancees identical()!)
  factory Jsonish(Json json, [String? serverToken]) {
    // Check cache
    String token;
    if (serverToken != null) {
      // EXPERIMENTAL:
      token = serverToken;
    } else {
      json = order(json);
      String ppJson = encoder.convert(json);
      token = sha1.convert(utf8.encode(ppJson)).toString();
    }
    if (_cache.containsKey(token)) return _cache[token]!;

    // EXPERIMENTAL: json not ordered when serverToken != null.
    // EXPERIMENTAL: Likely missing [previous, signature], can't compute token, can't verify sig.
    Jsonish fresh = Jsonish._internal(Map.unmodifiable(json), token);

    // Update cache
    _cache[token] = fresh;

    return fresh;
  }

  // Same as factory constructor, but can't be a constructor because async crypto.
  static Future<Jsonish> makeVerify(Json json, StatementVerifier verifier) async {
    String signature = json['signature']!;

    // Check cache.
    Json ordered = order(json);
    String ppJson = encoder.convert(ordered);
    String token = sha1.convert(utf8.encode(ppJson)).toString();
    if (_cache.containsKey(token)) {
      // In cache, that signature has already been verified, skip the crypto if the signature is same.
      Jsonish cached = _cache[token]!;
      if (cached['signature'] != signature) throw Exception('!verified');
      return cached;
    }

    // Verify
    Json orderedWithoutSig = order(Map.from(json)..removeWhere((k, v) => k == 'signature'));
    String ppJsonWithoutSig = encoder.convert(orderedWithoutSig);
    bool verified = await verifier.verify(json, ppJsonWithoutSig, signature);
    if (!verified) throw Exception('!verified');

    Jsonish fresh = Jsonish._internal(Map.unmodifiable(ordered), token);

    // Update cache
    _cache[token] = fresh;

    return fresh;
  }

  static Future<Jsonish> makeSign(Json json, StatementSigner signer) async {
    assert(!json.containsKey('signature'));

    Json ordered = order(json);
    String ppJson = encoder.convert(ordered); // no signature yet
    final String signature = await signer.sign(json, ppJson);
    ordered['signature'] = signature; // add signature
    ppJson = encoder.convert(ordered);
    final String token = sha1.convert(utf8.encode(ppJson)).toString();

    // Check cache.
    if (_cache.containsKey(token)) {
      // In cache, that signature is good, but why not be sure.
      Jsonish cached = _cache[token]!;
      assert(signature == cached['signature']);
      return cached;
    }

    Jsonish fresh = Jsonish._internal(Map.unmodifiable(ordered), token);

    // Update cache
    _cache[token] = fresh;

    return fresh;
  }

  Jsonish._internal(this._json, this._token);

  static dynamic order(dynamic value) {
    if (value is String || value is num || value is bool) {
      return value;
    } else if (value is Map) {
      String? signature = value['signature']; // signature last
      List list = List.of(value.entries)..sort((x, y) => compareKeys(x.key, y.key));
      LinkedHashMap<String, dynamic> orderedMap = LinkedHashMap<String, dynamic>();
      for (MapEntry entry in list.whereNot((e) => (e.key == 'signature'))) {
        orderedMap[entry.key] = Jsonish.order(entry.value);
      }
      if (signature != null) orderedMap['signature'] = signature;
      return orderedMap;
    } else if (value is List) {
      return value.map(order).toList();
    } else {
      throw Exception('Unexpected: (${value.runtimeType}) $value');
    }
  }

  // CODE: Try to reduce uses and switch to []
  Json get json => _json;

  String get token => _token;
  String get ppJson => encoder.convert(json);

  dynamic operator [](String key) => _json[key];
  bool containsKey(String key) => _json.containsKey(key);
  Iterable get keys => _json.keys;
  Iterable get values => _json.values;

  // Good ol' identity== should work.
  // @override
  // bool operator ==(Object other);

  // Jsonish instances from the factory constructor are distinct, and so default should work.
  // @override
  // int get hashCode => _token.hashCode;

  @override
  String toString() => _json.values.join(':');
}

// CODE: This is overused and can probably be eliminated if Jsonish becomes Json or token.
String getToken(dynamic x) {
  assert(x != null);
  if (x is Json) {
    return Jsonish(x).token;
  } else if (x is String) {
    return x;
  } else {
    throw Exception(x.runtimeType.toString());
  }
}
