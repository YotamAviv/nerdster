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
  final String domain;
  final FirebaseFirestore? firestore;
  final Map<String, dynamic> Function()? writeAuthHook;
  final Map<String, dynamic> Function()? readAuthHook;
  const _Registration({
    required this.domain,
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
/// ## Architecture: per-config roots with inject fanout
///
/// Each unique (exportUrl, streamKey, excludeTypes, distinct) gets its own
/// [_CachedSource<Statement>] root. [getChannel<T>] returns a [FilteredChannel<T>]
/// backed by the matching root:
///   - reads: delegates to root and filters to type T via `whereType<T>()`
///   - writes: delegates to root so head tracking is always on the root
///
/// [excludeTypes] is passed to the server (server-side filtering); [FilteredChannel]
/// also filters locally so the typed view never sees excluded types.
///
/// When a root injects an optimistic write, it fans out to every other root for the
/// same stream so the statement is immediately visible in all channels regardless of
/// excludeTypes. Fanout is skipped for a sibling that has not yet fetched the issuer
/// (no fetch-to-satisfy) and for statement types that are excluded by the sibling.
late ChannelFactory channelFactory;

class ChannelFactory {
  final FireChoice fireChoice;
  final ValueListenable<bool>? skipVerify;
  final Map<String, _Registration> _registrations = {};

  /// One root per unique (exportUrl, streamKey, excludeTypes, distinct) combination.
  final Map<String, _CachedSource<Statement>> _rootChannels = {};

  /// All roots for a given exportUrl/streamKey, across all excludeTypes/distinct variants.
  /// Used to fan out optimistic injects across all roots for the same stream.
  final Map<String, List<_CachedSource<Statement>>> _streamRoots = {};

  /// For unit tests only: substitutes this writer into every new root channel instead
  /// of the default. Set before calling [getChannel]. Does not affect already-created roots.
  @visibleForTesting
  StatementWriter<Statement>? testWriterOverride;

  /// Called when a background network write fails. The infrastructure has already cleared
  /// its own caches before calling this; the app must clean up its own state
  /// (e.g. statement caches, Jsonish cache, sign-in state) and prompt the user to reload.
  ///
  /// Must be [Future<void>] — the infrastructure awaits it so the UI can finish recovery
  /// before any further operations proceed.
  ///
  /// If null and a write fails, [FlutterError.reportError] is called (crashes in debug).
  Future<void> Function(Object)? onWriteError;

  ChannelFactory(this.fireChoice, {this.skipVerify, this.onWriteError});

  final Map<String, String> _redirects = {};

  /// Optionally register a domain to override defaults.
  ///
  /// Registration is only required when you need non-default behaviour:
  /// auth hooks, or a [firestore] instance for fireChoice == fake.
  /// Unregistered domains are served directly from `https://export.[domain]` /
  /// `https://write.[domain]`, with emulator remapping applied via [registerRedirect].
  /// For emulator write URLs, include the Cloud Function name in the redirect target.
  void register(
    String domain, {
    FirebaseFirestore? firestore,
    Map<String, dynamic> Function()? writeAuthHook,
    Map<String, dynamic> Function()? readAuthHook,
  }) {
    _registrations['https://export.$domain'] = _Registration(
      domain: domain,
      firestore: firestore,
      writeAuthHook: writeAuthHook,
      readAuthHook: readAuthHook,
    );
  }

  /// Redirect [from] to [to] when resolving URLs. Used for emulator setup.
  void registerRedirect(String from, String to) => _redirects[from] = to;

  /// Translates a canonical prod URL to the active environment's equivalent.
  String resolveUrl(String url) => _redirects[url] ?? url;

  /// Returns a [FilteredChannel<T>] backed by a root for [exportUrl]/[streamKey].
  ///
  /// Each unique (exportUrl, streamKey, excludeTypes, distinct) gets its own root.
  /// [excludeTypes] is passed to the server so it omits those types from responses.
  /// Type filtering is also applied locally by [FilteredChannel] via [whereType<T>()].
  ///
  /// Optimistic injects are fanned out across all roots for the same stream so
  /// that a write through any channel is immediately visible in all channels.
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

  static String _domainOf(String exportUrl) {
    final host = Uri.parse(exportUrl).host;
    assert(host.startsWith('export.'), 'exportUrl host must start with "export.": $exportUrl');
    return host.substring('export.'.length);
  }

  _CachedSource<Statement> _createRoot(String exportUrl, String streamKey,
      {List<String> excludeTypes = const [], bool distinct = true}) {
    final reg = _registrations[exportUrl];
    final streamKey2 = '$exportUrl/$streamKey';
    final siblings = _streamRoots.putIfAbsent(streamKey2, () => []);

    final _CachedSource<Statement> root;
    if (fireChoice == FireChoice.fake) {
      assert(reg?.firestore != null,
          'register() with firestore required for "$exportUrl" in fake mode');
      final source = DirectFirestoreSource<Statement>(reg!.firestore!,
          streamId: streamKey,
          allStreams: const ['statements'],
          skipVerify: skipVerify);
      final writer = testWriterOverride ??
          DirectFirestoreWriter<Statement>(reg.firestore!, streamId: streamKey);
      root = _CachedSource<Statement>(source, writer, () => onWriteError, () => siblings,
          excludeTypes: excludeTypes, distinct: distinct);
    } else {
      final domain = reg?.domain ?? _domainOf(exportUrl);
      final source = _CloudFunctionsSource<Statement>(
        baseUrl: resolveUrl(exportUrl),
        verifier: OouVerifier(),
        skipVerify: skipVerify,
        authHook: reg?.readAuthHook,
        excludeTypes: excludeTypes,
        paramsOverride: {'omit': <String>[], 'distinct': distinct ? 'true' : 'false'},
      );
      final writer = testWriterOverride ??
          _CloudFunctionsWriter<Statement>(
            resolveUrl('https://write.$domain'),
            streamKey,
            authHook: reg?.writeAuthHook,
          );
      root = _CachedSource<Statement>(source, writer, () => onWriteError, () => siblings,
          excludeTypes: excludeTypes, distinct: distinct);
    }
    siblings.add(root);
    return root;
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

  /// Creates a new [ChannelFactory] with the same [fireChoice], [skipVerify],
  /// registrations, and redirects, but with empty root and sibling caches.
  ///
  /// Use this when you need a fully independent client — one whose optimistic
  /// injects do not fan out to the original factory's channels. Typical use:
  /// testing previous-conflict or concurrent-write scenarios where two clients
  /// must start with divergent cached state.
  ChannelFactory fork() {
    final f = ChannelFactory(fireChoice, skipVerify: skipVerify);
    for (final e in _registrations.entries) {
      f._registrations[e.key] = e.value;
    }
    for (final e in _redirects.entries) {
      f.registerRedirect(e.key, e.value);
    }
    return f;
  }

  /// Clears all root channel caches. Does not affect underlying Firestore data.
  Future<void> clearCache() async {
    for (final ch in _rootChannels.values) {
      await ch.clear();
    }
    _rootChannels.clear();
    _streamRoots.clear();
  }
}

// ─── _CachedSource ───────────────────────────────────────────────────────────

class _CachedSource<T extends Statement> implements StatementChannel<T> {
  final StatementSource<T> _source;
  final StatementWriter<T>? _writer;

  /// Late-bound getter: read at error time so tests can swap [ChannelFactory.onWriteError].
  final Future<void> Function(Object)? Function() _getOnWriteError;

  /// Late-bound: returns all roots for this stream (including self). Read at inject time
  /// so newly registered siblings are always visible.
  final List<_CachedSource<Statement>> Function() _getSiblings;

  /// Statement type strings this root does not store (server-side filtered).
  /// Used by [_injectFromSibling] to skip statements of excluded types.
  final List<String> _excludeTypes;

  final VoidCallback? optimisticConcurrencyFunc;
  final bool _distinct;

  final Map<String, List<T>> _fullCache = {};
  final Map<String, (String, List<T>)> _partialCache = {};
  final Map<String, SourceError> _errorCache = {};
  final Map<String, Future<void>> _pushQueues = {};

  _CachedSource(this._source, this._writer, this._getOnWriteError, this._getSiblings, {
    List<String> excludeTypes = const [],
    this.optimisticConcurrencyFunc,
    bool distinct = true,
  }) : _excludeTypes = excludeTypes, _distinct = distinct;

  @override
  List<SourceError> get errors => List.unmodifiable(_errorCache.values);

  @override
  @override
  Future<void> clear() async {
    for (final f in List.of(_pushQueues.values)) {
      await f.catchError((_) {});
    }
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
        assert(_fullCache.containsKey(issuerId),
            'Channel must already be current before push — do not add a fetch() call just to satisfy this; the caller should have fetched this channel as part of normal operation');
        final ExpectedPrevious head = _fullCache[issuerId]!.isEmpty
            ? const ExpectedPrevious(null)
            : ExpectedPrevious(_fullCache[issuerId]!.first.token);

        // Sign locally and inject into cache so the UI can update without waiting.
        final Json jsonWithPrevious = Map.from(json);
        if (head.token != null) jsonWithPrevious['previous'] = head.token!;
        final Jsonish jsonish = await Jsonish.makeSign(jsonWithPrevious, signer);
        final T statement = Statement.make(jsonish) as T;
        _inject(statement);
        completer.complete(statement);

        // Await the network write — the queue chain stays here until the write
        // completes so that the next push reads the correct head from Firestore.
        try {
          await _writer.push(json, signer,
              previous: head,
              optimisticConcurrencyFailed: optimisticConcurrencyFailed ?? optimisticConcurrencyFunc);
        } catch (e, stack) {
          // Clear own state before calling the handler so clearCache() called
          // from within the handler doesn't deadlock on these push queues.
          _fullCache.clear();
          _partialCache.clear();
          _errorCache.clear();
          _pushQueues.clear();
          final handler = _getOnWriteError();
          if (handler != null) {
            await handler(e);
          } else {
            FlutterError.reportError(FlutterErrorDetails(
              exception: e,
              stack: stack,
              library: 'oneofus_common',
              context: ErrorDescription('background write failed with no onWriteError handler registered on ChannelFactory'),
            ));
          }
        }
      } catch (e, stack) {
        if (!completer.isCompleted) completer.completeError(e, stack);
      }
    });
    return completer.future;
  }

  void _inject(T statement) {
    _injectLocal(statement);
    for (final sibling in _getSiblings()) {
      if (sibling == this) continue;
      sibling._injectFromSibling(statement);
    }
  }

  void _injectLocal(T statement) {
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

  /// Fanout inject from a sibling root. Does not check the `previous` chain because
  /// sibling caches may diverge when excludeTypes differ (e.g. a sibling that omits
  /// dismiss statements has a different chain head than the writing root). Simply
  /// inserts at head — new statements always have the latest time.
  void _injectFromSibling(Statement statement) {
    if (_excludeTypes.contains(statement['statement'])) return;
    final String iToken = statement.iToken;
    if (!_fullCache.containsKey(iToken)) return;
    final T? typed = statement is T ? statement : null;
    if (typed == null) return;
    final List<T> history = List.of(_fullCache[iToken]!);
    history.insert(0, typed);
    if (_distinct) {
      final String sig = typed.getDistinctSignature();
      history.removeWhere((s) => s != typed && s.getDistinctSignature() == sig);
    }
    _fullCache[iToken] = history;
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
