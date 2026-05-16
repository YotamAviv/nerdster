import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/filtered_channel.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';

enum FireChoice { fake, emulator, prod }

// fake: DirectFirestoreSource/Writer — bypasses CF, hits Firestore directly (unit tests only).
// emulator: CloudFunctionsSource/Writer pointed at local emulator URLs. Does not use firestore.
// prod: CloudFunctionsSource/Writer pointed at production URLs. Does not use firestore.
class _Registration {
  final String exportUrl;
  final String functionsUrl;
  final String writeEndpoint;
  final FirebaseFirestore? firestore;
  final Map<String, dynamic> Function()? writeAuthHook;
  final Map<String, dynamic> Function()? readAuthHook;
  const _Registration({
    required this.exportUrl,
    required this.functionsUrl,
    this.writeEndpoint = 'write2',
    this.firestore,
    this.writeAuthHook,
    this.readAuthHook,
  });
}

/// The single entry point for all statement channels.
///
/// Initialize once at startup (main() or test setUp), then call getChannel()
/// wherever a stream is needed. All fireChoice branching is contained here;
/// no other code in the app should branch on fireChoice.
///
/// ## Architecture: FilteredChannel over a shared root
///
/// Each domain/streamKey has exactly one root [_CachedSource<Statement>] that fetches
/// and caches ALL statement types from that stream. [getChannel<T>] returns a
/// [FilteredChannel<T>] that is a lightweight facade:
///   - reads: delegates to root and filters results to type T via `whereType<T>()`
///   - writes: delegates directly to root so head tracking is always correct
///
/// This ensures optimistic locking works correctly in mixed-type streams
/// (e.g. both ContentStatements and DismissStatements in statements/statements),
/// because head tracking is centralised in the single root channel.
///
/// The [excludeTypes] parameter is accepted for call-site compatibility but
/// ignored: type filtering is performed locally by [FilteredChannel].
late ChannelFactory channelFactory;

class ChannelFactory {
  final FireChoice fireChoice;
  final ValueListenable<bool>? skipVerify;
  final Map<String, _Registration> _registrations = {};

  /// One root channel per exportUrl/streamKey; all typed FilteredChannels share these.
  final Map<String, _CachedSource<Statement>> _rootChannels = {};

  ChannelFactory(this.fireChoice, {this.skipVerify});

  /// Register a domain's backend.
  ///
  /// [exportUrl] and [functionsUrl] are the production URLs.
  /// [emulatorExportUrl] and [emulatorFunctionsUrl] are used when
  /// fireChoice == emulator.
  /// [firestore] is required when fireChoice == fake.
  void register({
    required String exportUrl,
    required String functionsUrl,
    String? emulatorExportUrl,
    String? emulatorFunctionsUrl,
    String writeEndpoint = 'write2',
    FirebaseFirestore? firestore,
    Map<String, dynamic> Function()? writeAuthHook,
    Map<String, dynamic> Function()? readAuthHook,
  }) {
    final resolvedExport =
        fireChoice == FireChoice.emulator && emulatorExportUrl != null
            ? emulatorExportUrl
            : exportUrl;
    final resolvedFunctions =
        fireChoice == FireChoice.emulator && emulatorFunctionsUrl != null
            ? emulatorFunctionsUrl
            : functionsUrl;
    _registrations[exportUrl] = _Registration(
      exportUrl: resolvedExport,
      functionsUrl: resolvedFunctions,
      writeEndpoint: writeEndpoint,
      firestore: firestore,
      writeAuthHook: writeAuthHook,
      readAuthHook: readAuthHook,
    );
  }

  /// Returns a [FilteredChannel<T>] backed by a shared root for [exportUrl]/[streamKey].
  ///
  /// Roots are keyed by exportUrl, streamKey, and excludeTypes together, so channels with
  /// different excludeTypes get different roots and different CF fetch configurations.
  /// Writable channels must share the same root — always use the same excludeTypes
  /// (typically none) for channels that call push().
  StatementChannel<T> getChannel<T extends Statement>(
    String exportUrl,
    String streamKey, {
    List<String> excludeTypes = const [],
    bool distinct = true,
  }) {
    final sorted = List.of(excludeTypes)..sort();
    String cacheKey = sorted.isEmpty
        ? '$exportUrl/$streamKey'
        : '$exportUrl/$streamKey:excl=${sorted.join(",")}';
    if (!distinct) cacheKey = '$cacheKey:nodistinct';
    final root = _rootChannels.putIfAbsent(
      cacheKey,
      () => _createRoot(exportUrl, streamKey, excludeTypes: sorted, distinct: distinct),
    );
    return FilteredChannel<T>(root);
  }

  _CachedSource<Statement> _createRoot(String exportUrl, String streamKey,
      {List<String> excludeTypes = const [], bool distinct = true}) {
    final reg = _registrations[exportUrl];
    assert(reg != null, 'No registration for "$exportUrl"');
    if (fireChoice == FireChoice.fake) {
      assert(reg!.firestore != null,
          'register() must provide firestore for fireChoice.fake');
      final source = DirectFirestoreSource<Statement>(reg!.firestore!,
          streamId: streamKey,
          allStreams: const ['statements'],
          skipVerify: skipVerify);
      final writer =
          DirectFirestoreWriter<Statement>(reg.firestore!, streamId: streamKey);
      return _CachedSource<Statement>(source, writer, null, distinct);
    } else {
      final source = _CloudFunctionsSource<Statement>(
        baseUrl: reg!.exportUrl,
        verifier: OouVerifier(),
        skipVerify: skipVerify,
        authHook: reg.readAuthHook,
        excludeTypes: excludeTypes,
        paramsOverride: {'omit': <String>[], 'distinct': distinct ? 'true' : 'false'},
      );
      final writer = _CloudFunctionsWriter<Statement>(
        '${reg.functionsUrl}/${reg.writeEndpoint}',
        streamKey,
        authHook: reg.writeAuthHook,
      );
      return _CachedSource<Statement>(source, writer, null, distinct);
    }
  }

  /// DEV/INTEGRATION TESTING ONLY.
  ///
  /// Creates a [_CloudFunctionsSource] directly, bypassing channel caching,
  /// auth hooks, and skipVerify. Pass the [_testOnlyToken] defined as a
  /// top-level private in your dev/integration test file — importing that
  /// file into production code is the intended barrier against misuse.
  StatementSource<T> rawSourceForTesting<T extends Statement>(
    Object testOnlyToken, {
    required String baseUrl,
    String? statementType,
    Json? paramsOverride,
    StatementVerifier? verifier,
  }) =>
      _CloudFunctionsSource<T>(
        baseUrl: baseUrl,
        statementType: statementType,
        verifier: verifier ?? OouVerifier(),
        paramsOverride: paramsOverride,
      );

  /// Returns the raw Firestore instance registered for [domain], or null if none.
  FirebaseFirestore? firestoreFor(String exportUrl) => _registrations[exportUrl]?.firestore;

  /// Clears all root channel caches. Does not affect underlying Firestore data.
  void clearCache() {
    for (final ch in _rootChannels.values) {
      ch.clear();
    }
    _rootChannels.clear();
  }
}

// ─── _CachedSource ───────────────────────────────────────────────────────────

class _CachedSource<T extends Statement> implements StatementChannel<T> {
  final StatementSource<T> _source;
  final StatementWriter<T>? _writer;
  final bool _distinct;

  final Map<String, List<T>> _fullCache = {};
  final Map<String, (String, List<T>)> _partialCache = {};
  final Map<String, SourceError> _errorCache = {};
  final Map<String, Future<void>> _pushQueues = {};

  final VoidCallback? optimisticConcurrencyFunc;

  _CachedSource(this._source, [this._writer, this.optimisticConcurrencyFunc, bool distinct = true])
      : _distinct = distinct;

  @override
  List<SourceError> get errors => List.unmodifiable(_errorCache.values);

  @override
  void clear() {
    _fullCache.clear();
    _partialCache.clear();
    _errorCache.clear();
  }

  @override
  void resetRevokeAt() {
    _partialCache.clear();
  }

  @override
  Future<T> push(Json json, StatementSigner signer,
      {ExpectedPrevious? previous, VoidCallback? optimisticConcurrencyFailed}) {
    if (_writer == null) throw UnimplementedError('No writer');
    if (previous != null) throw StateError('CachedSource.push, no previous parameter');

    final String issuerId = getToken(json['I']);
    final completer = Completer<T>();
    final Future<void> prev = _pushQueues[issuerId] ?? Future.value();
    _pushQueues[issuerId] = prev.catchError((_) {}).then((_) async {
      try {
        assert(_fullCache.containsKey(issuerId), 'fetch before push');
        final ExpectedPrevious head = _fullCache[issuerId]!.isEmpty
            ? const ExpectedPrevious(null)
            : ExpectedPrevious(_fullCache[issuerId]!.first.token);
        final T statement = await _writer.push(json, signer,
            previous: head,
            optimisticConcurrencyFailed: optimisticConcurrencyFailed ?? optimisticConcurrencyFunc);
        _inject(statement);
        completer.complete(statement);
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });
    return completer.future;
  }

  void _inject(T statement) {
    assert(statement.iToken.isNotEmpty);
    final String token = statement.iToken;
    if (!_fullCache.containsKey(token)) return;
    final List<T> history = List.of(_fullCache[token]!);

    final String? previous = statement['previous'];
    if (history.isEmpty) {
      if (previous != null && previous.isNotEmpty) {
        throw Exception('Cache inconsistency detected for token $token (expected Genesis)');
      }
    } else {
      final T head = history.first;
      if (previous != head.token) {
        throw Exception('Cache inconsistency detected for token $token (prev $previous != head ${head.token})');
      }
    }

    history.insert(0, statement);
    if (_distinct) {
      final String sig = statement.getDistinctSignature();
      history.removeWhere((s) => s != statement && s.getDistinctSignature() == sig);
    }
    _fullCache[token] = history;
  }

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    final Map<String, List<T>> results = {};
    final Map<String, String?> missing = {};

    for (final MapEntry<String, String?> entry in keys.entries) {
      final String token = entry.key;
      final String? revokeAt = entry.value;

      if (_errorCache.containsKey(token)) continue;

      if (_fullCache.containsKey(token)) {
        if (revokeAt == null) {
          results[token] = List.unmodifiable(_fullCache[token]!);
        } else {
          final List<T> full = _fullCache[token]!;
          final int idx = full.indexWhere((T s) => s.token == revokeAt);
          if (idx >= 0) {
            results[token] = List.unmodifiable(full.sublist(idx));
          } else {
            missing[token] = revokeAt;
          }
        }
      } else if (revokeAt != null &&
          _partialCache.containsKey(token) &&
          _partialCache[token]!.$1 == revokeAt) {
        results[token] = List.unmodifiable(_partialCache[token]!.$2);
      } else {
        missing[token] = revokeAt;
      }
    }

    if (missing.isNotEmpty) {
      final Map<String, List<T>> fetched = await _source.fetch(missing);

      for (final String token in missing.keys) {
        final SourceError? error =
            _source.errors.where((SourceError e) => e.token == token).firstOrNull;
        if (error != null) {
          _errorCache[token] = error;
          continue;
        }

        final List<T> statements = fetched[token] ?? [];
        final String? revokeAt = missing[token];

        if (revokeAt == null) {
          _fullCache[token] = statements;
        } else {
          _partialCache[token] = (revokeAt, statements);
        }
        results[token] = List.unmodifiable(statements);
      }
    }

    return results;
  }
}

// ─── _CloudFunctionsSource ───────────────────────────────────────────────────

class _CloudFunctionsSource<T extends Statement> implements StatementSource<T> {
  final String baseUrl;

  /// The statement type string used as fallback when the server omits the 'statement' field.
  final String? statementType;

  final List<String> excludeTypes;
  final http.Client client;
  final StatementVerifier verifier;
  final ValueListenable<bool>? skipVerify;
  final Json? paramsOverride;
  final Map<String, dynamic> Function()? authHook;
  final Map<String, SourceError> _errors = {};

  static const Json _paramsProto = {
    "distinct": "true",
    "orderStatements": "false",
    "includeId": "true",
    "checkPrevious": "true",
    "omit": ['statement', 'I'],
  };

  _CloudFunctionsSource({
    required this.baseUrl,
    this.statementType,
    this.excludeTypes = const [],
    http.Client? client,
    required this.verifier,
    this.skipVerify,
    this.paramsOverride,
    this.authHook,
  }) : client = client ?? http.Client();

  @override
  List<SourceError> get errors => List.unmodifiable(_errors.values);

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    for (final key in keys.keys) {
      _errors.remove(key);
    }
    if (keys.isEmpty) return {};

    final List<dynamic> spec = keys.entries.map((e) {
      if (e.value == null) return e.key;
      return {e.key: e.value};
    }).toList();

    final Json params = Map.of(_paramsProto);
    if (paramsOverride != null) params.addAll(paramsOverride!);
    if (excludeTypes.isNotEmpty) params['excludeTypes'] = excludeTypes;
    if (authHook != null) {
      for (final entry in authHook!().entries) {
        final value = entry.value;
        params[entry.key] = value is String ? value : jsonEncode(value);
      }
    }
    params['spec'] = jsonEncode(spec);

    final Uri uri = Uri.parse(baseUrl).replace(queryParameters: params);
    final http.Request request = http.Request('GET', uri);
    final http.StreamedResponse response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch statements from $baseUrl: ${response.statusCode}');
    }

    final Map<String, List<T>> results = {};
    final bool skipCheck = skipVerify?.value ?? false;

    await for (final String line
        in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;

      final Json jsonToken2Statements = jsonDecode(line);

      for (final MapEntry<String, dynamic> entry in jsonToken2Statements.entries) {
        final String token = entry.key;
        final dynamic value = entry.value;

        if (value is Map && value.containsKey('error')) {
          _errors[token] = SourceError(value['error'], token: token);
          results.remove(token);
          continue;
        }

        final List<dynamic> statementsJson = value as List<dynamic>;
        final List<T> list = results.putIfAbsent(token, () => []);
        final Map<String, String> iJson = {'I': token};

        try {
          for (final dynamic json in statementsJson) {
            if (!json.containsKey('I')) {
              final Jsonish? cached = Jsonish.find(token);
              json['I'] = cached != null ? cached.json : iJson;
            }
            if (!json.containsKey('statement') && statementType != null) {
              json['statement'] = statementType!;
            }

            final String? serverToken = json['id'];
            if (serverToken != null) json.remove('id');

            Jsonish jsonish;
            if (!skipCheck) {
              try {
                jsonish = await Jsonish.makeVerify(json, verifier);
              } catch (e) {
                throw SourceError('Invalid Signature: $e', token: token, originalError: e);
              }
            } else {
              jsonish = Jsonish(json, serverToken);
            }

            list.add(Statement.make(jsonish) as T);
          }
        } catch (e) {
          _errors[token] = e is SourceError
              ? e
              : SourceError('Error processing statements: $e', token: token, originalError: e);
          results.remove(token);
        }
      }
    }

    for (final token in results.keys) {
      results[token] = List.unmodifiable(results[token]!);
    }

    return results;
  }
}

// ─── _CloudFunctionsWriter ───────────────────────────────────────────────────

class _CloudFunctionsWriter<T extends Statement> implements StatementWriter<T> {
  final String writeUrl;
  final String streamId;
  final Map<String, dynamic> Function()? authHook;
  final Map<String, Future<void>> _writeQueues = {};

  _CloudFunctionsWriter(this.writeUrl, this.streamId, {this.authHook});

  @override
  Future<T> push(Json json, StatementSigner signer,
      {ExpectedPrevious? previous, VoidCallback? optimisticConcurrencyFailed}) async {
    assert(!json.containsKey('previous'), 'unexpected');

    final String issuerToken = getToken(json['I']);

    if (optimisticConcurrencyFailed != null) {
      if (previous != null && previous.token != null) json['previous'] = previous.token!;
      final jsonish = await Jsonish.makeSign(json, signer);
      final Future<void> prev = _writeQueues[issuerToken] ?? Future.value();
      _writeQueues[issuerToken] = prev.catchError((_) {}).then((_) async {
        try {
          await _callCF(jsonish);
        } catch (_) {
          optimisticConcurrencyFailed();
        }
      });
      return Statement.make(jsonish) as T;
    }

    final completer = Completer<T>();
    final Future<void> prev = _writeQueues[issuerToken] ?? Future.value();
    _writeQueues[issuerToken] = prev.catchError((_) {}).then((_) async {
      try {
        final Json j = Map.from(json);
        if (previous?.token != null) j['previous'] = previous!.token!;
        final Jsonish jsonish = await Jsonish.makeSign(j, signer);
        await _callCF(jsonish);
        completer.complete(Statement.make(jsonish) as T);
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });
    return completer.future;
  }

  Future<void> _callCF(Jsonish jsonish) async {
    final response = await http.post(
      Uri.parse(writeUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'statement': jsonish.json,
        'streamName': streamId,
        if (authHook != null) ...authHook!(),
      }),
    );
    if (response.statusCode != 200) {
      debugPrint('_CloudFunctionsWriter._callCF: ${response.statusCode} ${response.body}');
      throw Exception('write failed: ${response.statusCode} ${response.body}');
    }
  }
}
