import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:oneofus_common/cached_source.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/cloud_functions_writer.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';

enum FireChoice { fake, emulator, prod }

class _Registration {
  final String exportUrl;
  final String functionsUrl;
  final String writeEndpoint;
  final FirebaseFirestore? firestore;
  const _Registration(
      {required this.exportUrl,
      required this.functionsUrl,
      this.writeEndpoint = 'write2',
      this.firestore});
}

/// The single entry point for all statement channels.
///
/// Initialize once at startup (main() or test setUp), then call getChannel()
/// wherever a stream is needed. All fireChoice branching is contained here;
/// no other code in the app should branch on fireChoice.
late ChannelFactory channelFactory;

class ChannelFactory {
  final FireChoice fireChoice;
  final ValueListenable<bool>? skipVerify;
  final Map<String, _Registration> _registrations = {};
  final Map<String, StatementChannel> _cache = {};

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
    );
  }

  /// Returns the cached channel for [domain]/[streamKey], creating it if needed.
  ///
  /// [allStreams] lists all stream collections that share the same issuer key
  /// space — used by the export CF and DirectFirestoreSource to locate revokeAt
  /// tokens across collections.
  StatementChannel<T> getChannel<T extends Statement>(
    String domain,
    String streamKey, {
    List<String> allStreams = const [],
  }) {
    final cacheKey = '$domain/$streamKey';
    return _cache.putIfAbsent(
            cacheKey, () => _create<T>(domain, streamKey, allStreams))
        as StatementChannel<T>;
  }

  StatementChannel<T> _create<T extends Statement>(
      String domain, String streamKey, List<String> allStreams) {
    final reg = _registrations[domain];
    assert(reg != null, 'No registration for domain "$domain"');
    final streams = allStreams.isEmpty ? [streamKey] : allStreams;
    if (fireChoice == FireChoice.fake) {
      assert(reg!.firestore != null,
          'register() must provide firestore for fireChoice.fake');
      final source = DirectFirestoreSource<T>(reg!.firestore!,
          streamId: streamKey, allStreams: streams, skipVerify: skipVerify);
      final writer =
          DirectFirestoreWriter<T>(reg.firestore!, streamId: streamKey);
      return CachedSource<T>(source, writer);
    } else {
      final source = CloudFunctionsSource<T>(
        baseUrl: reg!.exportUrl,
        streamId: streamKey,
        allStreams: streams,
        verifier: OouVerifier(),
        skipVerify: skipVerify,
      );
      final writer = CloudFunctionsWriter<T>('${reg.functionsUrl}/${reg.writeEndpoint}', streamKey);
      return CachedSource<T>(source, writer);
    }
  }

  /// Returns the raw Firestore instance registered for [domain], or null if none.
  FirebaseFirestore? firestoreFor(String domain) => _registrations[domain]?.firestore;

  /// Clears the channel cache (and each channel's statement cache).
  /// Does not affect underlying Firestore data.
  void clearCache() {
    for (final ch in _cache.values) {
      ch.clear();
    }
    _cache.clear();
  }
}
