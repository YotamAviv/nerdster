// SourceFactory is the single authority for all statement sources and writers.
// All fireChoice branching lives here — nowhere else in the app should check fireChoice
// to decide how to read or write statements.
//
// Two backends:
//   fake  — uses FakeFirebaseFirestore (DirectFirestore*). Required for unit tests
//           because Firebase is not supported in the Dart test environment.
//   real  — always uses Cloud Functions (emulator or production). This is the path
//           that most closely resembles real-world behavior and is used for all
//           emulator and production runs. The interfaces are designed so that most
//           app logic is unit-testable via the fake path in a way that mirrors the
//           real cloud-functions path as closely as possible.
//
// forContent() and forDis() return shared StatementChannel instances. Every caller gets
// the same object, which means they share the same in-memory cache and write queue.
// This is required for correctness: each stream forms a linked list (each statement
// references the previous one), so writing to a stream requires knowing its current
// head. The shared StatementChannel tracks the head after every write, serializing
// concurrent writes per issuer so the server never sees a stale "previous" token.
import 'package:nerdster/config.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:oneofus_common/cached_source.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/cloud_functions_writer.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/dismiss_statement.dart';

class SourceFactory {
  static final Map<String, StatementChannel> _sourceCache = {};
  static final Map<String, StatementWriter> _writerCache = {};

  static void reset() {
    _sourceCache.clear();
    _writerCache.clear();
  }

  static StatementWriter<T> _cachedWriter<T extends Statement>(
      String key, StatementWriter<T> Function() create) {
    return _writerCache.putIfAbsent(key, create) as StatementWriter<T>;
  }

  static StatementChannel<T> _cachedSource<T extends Statement>(
      String streamId, List<String> allStreams) {
    return _sourceCache.putIfAbsent(streamId, () {
      final StatementSource<T> source;
      final StatementWriter<T> writer;
      if (fireChoice == FireChoice.fake) {
        final firestore = FireFactory.find(kNerdsterDomain);
        source = DirectFirestoreSource<T>(
          firestore,
          streamId: streamId,
          allStreams: allStreams,
          skipVerify: Setting.get<bool>(SettingType.skipVerify),
        );
        writer = _cachedWriter('fake/$streamId',
            () => DirectFirestoreWriter<T>(firestore, streamId: streamId));
      } else {
        source = CloudFunctionsSource<T>(
          baseUrl: FirebaseConfig.contentUrl,
          streamId: streamId,
          allStreams: allStreams,
          verifier: OouVerifier(),
          skipVerify: Setting.get<bool>(SettingType.skipVerify),
        );
        writer = _cachedWriter('real/$streamId',
            () => CloudFunctionsWriter<T>(FirebaseConfig.nerdsterFunctionsUrl, streamId));
      }
      return CachedSource<T>(source, writer);
    }) as StatementChannel<T>;
  }

  /// Content pipeline: always export.nerdster.org (or its emulator redirect).
  static StatementChannel<ContentStatement> forContent() =>
      _cachedSource<ContentStatement>('statements', ['statements', 'dis']);

  /// Dis stream.
  // TODO(deferred): exporting dis statements and true-PoV-dis will need this source
  // to be fetchable for arbitrary delegate keys, not just the signed-in user.
  static StatementChannel<DismissStatement> forDis() =>
      _cachedSource<DismissStatement>('dis', ['statements', 'dis']);

  /// Trust stream — for demo/test use only.
  /// The real app never holds an identity key and therefore can never write trust statements.
  /// Only DemoKey and tests call this.
  static StatementChannel<TrustStatement> forTrust() {
    return _sourceCache.putIfAbsent('trust', () {
      final StatementSource<TrustStatement> source;
      final StatementWriter<TrustStatement> writer;
      if (fireChoice == FireChoice.fake) {
        final firestore = FireFactory.find(kOneofusDomain);
        source = DirectFirestoreSource<TrustStatement>(
          firestore,
          skipVerify: Setting.get<bool>(SettingType.skipVerify),
        );
        writer = _cachedWriter('fake/trust',
            () => DirectFirestoreWriter<TrustStatement>(firestore));
      } else {
        source = CloudFunctionsSource<TrustStatement>(
          baseUrl: FirebaseConfig.resolveUrl('https://export.one-of-us.net'),
          verifier: OouVerifier(),
          skipVerify: Setting.get<bool>(SettingType.skipVerify),
        );
        writer = _cachedWriter('real/trust',
            () => CloudFunctionsWriter<TrustStatement>(FirebaseConfig.oneofusFunctionsUrl, 'statements'));
      }
      return CachedSource<TrustStatement>(source, writer);
    }) as StatementChannel<TrustStatement>;
  }
}
