import 'package:flutter/foundation.dart'; // for ChangeNotifier and listEquals
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/measure.dart';
import 'package:nerdster/oneofus/merger.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

/// TRUE: can't compute (or lookup) signInState.centerReset from _signedInDelegateXXX (could be
/// 2 folks claiming same delegate)
///
/// Performance:
/// - Low priority?
/// - We should be processing after OneofusNet
/// - Unless we're not in the network (due to PoV) we shouldn't be fetching.
/// - In case we're not in the network, then we need to fetch everything for ourselves, oneofus and nerdster.
/// - Optimizations could include
///   - batch fetch delegates (after we know them)
///   - fetch our Oneofus statements in the same batches with OneofusNet
///   - fetch our delegate statements in the same batch as FollowNet
///   - (can't batch fetch replaced keys, must be sequential, at most degrees, same as OneofusNet)

class MyDelegateStatements extends Comp with ChangeNotifier {
  static final MyDelegateStatements _singleton = MyDelegateStatements._internal();
  static final Measure measure = Measure('myDelegateStatements');

  factory MyDelegateStatements() => _singleton;
  MyDelegateStatements._internal() {
    // Changes to delegates could be sync'd (fetched), (eg. user revokes delegate using phone app).
    addSupporter(oneofusNet);
    oneofusNet.addListener(listen);
    signInState.addListener(listen);
  }

  List<Fetcher> _fetchers = [];

  void listen() {
    setDirty();
    notifyListeners();
  }

  // (We don't cache the contents of fetchers, but if there was a way to listen for pushes, we could).
  Iterable<ContentStatement> get statements {
    assert(ready);
    return Merger(_fetchers.map((f) => f.statements)).toList().cast();
  }

  @override
  Future<void> process() async {
    throwIfSupportersNotReady();
    if (!b(signInState.centerReset)) return;
    measure.start();
    try {
      Map<String, String?> identities = {};
      Map<String, String?> delegates = {};
      await load(signInState.centerReset!, delegates, identities);

      // read those and get delegates
      await Fetcher.batchFetch(delegates, kNerdsterDomain, mName: 'MyDelegateStatements');

      _fetchers = [];
      for (MapEntry<String, String?> e in delegates.entries) {
        String token = e.key;
        String? revokeAt = e.value;
        Fetcher f = Fetcher(token, kNerdsterDomain);
        if (b(revokeAt)) f.setRevokeAt(revokeAt!);
        // TODO: This is sort of a fetcher bug or confusion. batchFetch doesn't load the cache,
        // but it preps for it. Work is done for verifying in that stage.
        // assert(f.isCached);
        if (!f.isCached) await f.fetch();
        _fetchers.add(f);
      }
    } finally {
      measure.stop();
    }
  }

  Future<void> load(
      String token, Map<String, String?> delegates, Map<String, String?> identities) async {
    Fetcher fetcher = Fetcher(token, kOneofusDomain);
    if (b(identities[token])) fetcher.setRevokeAt(identities[token]!);
    await fetcher.fetch();

    for (TrustStatement s in fetcher.statements.cast<TrustStatement>()) {
      if (s.verb == TrustVerb.delegate) {
        delegates[s.subjectToken] = s.revokeAt;
      }
    }

    for (TrustStatement s in fetcher.statements.cast<TrustStatement>()) {
      if (s.verb == TrustVerb.replace) {
        if (identities.length > oneofusNet.degrees) return;
        identities[s.subjectToken] = s.revokeAt;
        await load(s.subjectToken, identities, delegates);
      }
    }
  }
}
