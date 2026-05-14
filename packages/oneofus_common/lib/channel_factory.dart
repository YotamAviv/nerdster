import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:oneofus_common/cached_source.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/cloud_functions_writer.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/filtered_channel.dart';
import 'package:oneofus_common/oou_verifier.dart';
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
/// Each domain/streamKey has exactly one root [CachedSource<Statement>] that fetches
/// and caches ALL statement types from that stream. [getChannel<T>] returns a
/// [FilteredChannel<T>] that is a lightweight facade:
///   - reads: delegates to root and filters results to type T via whereType<T>()
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

  /// One root channel per domain/streamKey; all typed FilteredChannels share these.
  final Map<String, CachedSource<Statement>> _rootChannels = {};

  ChannelFactory(this.fireChoice, {this.skipVerify});

  /// Register a domain's backend.
  ///
  /// [exportUrl] and [functionsUrl] are the production URLs.
  /// [emulatorExportUrl] and [emulatorFunctionsUrl] are used when
  /// fireChoice == emulator.
  /// [firestore] is required when fireChoice == fake.
  void register(
    String domain, {
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
    _registrations[domain] = _Registration(
      exportUrl: resolvedExport,
      functionsUrl: resolvedFunctions,
      writeEndpoint: writeEndpoint,
      firestore: firestore,
      writeAuthHook: writeAuthHook,
      readAuthHook: readAuthHook,
    );
  }

  /// Returns a [FilteredChannel<T>] backed by a shared root for [domain]/[streamKey].
  ///
  /// Roots are keyed by domain, streamKey, and excludeTypes together, so channels with
  /// different excludeTypes get different roots and different CF fetch configurations.
  /// Writable channels must share the same root — always use the same excludeTypes
  /// (typically none) for channels that call push().
  StatementChannel<T> getChannel<T extends Statement>(
    String domain,
    String streamKey, {
    List<String> excludeTypes = const [],
  }) {
    final sorted = List.of(excludeTypes)..sort();
    final cacheKey = sorted.isEmpty
        ? '$domain/$streamKey'
        : '$domain/$streamKey:excl=${sorted.join(",")}';
    final root = _rootChannels.putIfAbsent(
      cacheKey,
      () => _createRoot(domain, streamKey, excludeTypes: sorted),
    );
    return FilteredChannel<T>(root);
  }

  CachedSource<Statement> _createRoot(String domain, String streamKey,
      {List<String> excludeTypes = const []}) {
    final reg = _registrations[domain];
    assert(reg != null, 'No registration for domain "$domain"');
    if (fireChoice == FireChoice.fake) {
      assert(reg!.firestore != null,
          'register() must provide firestore for fireChoice.fake');
      final source = DirectFirestoreSource<Statement>(reg!.firestore!,
          streamId: streamKey,
          allStreams: const ['statements'],
          skipVerify: skipVerify);
      final writer =
          DirectFirestoreWriter<Statement>(reg.firestore!, streamId: streamKey);
      return CachedSource<Statement>(source, writer);
    } else {
      final source = CloudFunctionsSource<Statement>(
        baseUrl: reg!.exportUrl,
        verifier: OouVerifier(),
        skipVerify: skipVerify,
        authHook: reg.readAuthHook,
        excludeTypes: excludeTypes,
        paramsOverride: const {'omit': <String>[], 'distinct': 'false'},
      );
      final writer = CloudFunctionsWriter<Statement>(
        '${reg.functionsUrl}/${reg.writeEndpoint}',
        streamKey,
        authHook: reg.writeAuthHook,
      );
      return CachedSource<Statement>(source, writer);
    }
  }

  /// Returns the raw Firestore instance registered for [domain], or null if none.
  FirebaseFirestore? firestoreFor(String domain) => _registrations[domain]?.firestore;

  /// Clears all root channel caches. Does not affect underlying Firestore data.
  void clearCache() {
    for (final ch in _rootChannels.values) {
      ch.clear();
    }
    _rootChannels.clear();
  }
}
