import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/follow/most_contexts.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/merger.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';
import 'package:nerdster/trust/trust1.dart';

typedef StatementFilter = Iterable<Statement> Function(Iterable<Statement>);

class FollowNet with Comp, ChangeNotifier {
  static final FollowNet _singleton = FollowNet._internal();
  factory FollowNet() => _singleton;
  FollowNet._internal() {
    // supporters
    addSupporter(oneofusNet);
    oneofusNet.addListener(listen);
    addSupporter(oneofusEquiv);
    oneofusEquiv.addListener(listen);
  }

  // vars
  String? _context;
  final MostContexts _mostContexts = MostContexts();
  final Map<String, Set<String>> _oneofus2delegates = <String, Set<String>>{};
  final Map<String, String> _delegate2oneofus = <String, String>{};
  final Map<String, Fetcher> _delegate2fetcher = <String, Fetcher>{};

  // interface
  String? get fcontext => _context;
  set fcontext(String? context) {
    _context = context;
    listen();
  }

  Iterable<String> get most => _mostContexts.most();

  Map<String, Set<String>> get oneofus2delegates => UnmodifiableMapView(_oneofus2delegates);
  Map<String, String> get delegate2oneofus => UnmodifiableMapView(_delegate2oneofus);
  Map<String, Fetcher> get delegate2fetcher => UnmodifiableMapView(_delegate2fetcher);

  Iterable<ContentStatement> getStatements(String oneofus) {
    assert(oneofusNet.network.containsKey(oneofus));
    Iterable<Iterable<Statement>> iiStatements =
        _oneofus2delegates[oneofus]!.map((delegate) => _delegate2fetcher[delegate]!.statements);
    Merger merger = Merger(iiStatements);
    // BUG: Bug manifested first time in production (oops) at content_statement.ContentStatement._internal.getDistinctSignature (content_statement.dart:108:51)
    // That's where ContentStatement uses the transformer on the subject because verb==follow.
    // But we follow Oneofus tokens, not Nerdster tokens, and so how did this ever work?
    // TODO: Make (or move code) a test case to Demo so that I can try following in the UI.
    // DONE: Add content to follow_net_test
    // FIX: [ContentStatement] no longer transforms subjecToken.
    // When do we need to transform subject?
    //   (OneofusNet doesn't want anything transformed.)
    //   NetNode wants both [iToken, subjectToken] transformed.
    Iterable<ContentStatement> dis = distinct(merger.cast<ContentStatement>(),
        transformer: (delegate) => followNet.delegate2oneofus[delegate]!).cast<ContentStatement>();
    return dis.cast<ContentStatement>();
  }

  // impl
  Future<Jsonish> insert(Json json) async {
    String iToken = getToken(json['I']);
    assert(signInState.signedInDelegate == iToken);
    Fetcher fetcher = Fetcher(iToken, kNerdsterDomain);
    Jsonish statement = await fetcher.push(json, signInState.signer!);
    listen();
    return statement;
  }

  void listen() {
    setDirty();
    notifyListeners();
  }

  // impl
  @override
  Future<void> process() async {
    assert(supportersReady); // Questionable
    _mostContexts.clear();
    FollowNode.clear();
    _delegate2oneofus.clear();
    _oneofus2delegates.clear();
    _delegate2fetcher.clear();

    Iterable<String> network;
    if (b(fcontext)) {
      Trust1 trust1 = Trust1();
      FollowNode.clear();
      LinkedHashMap<String, Node> canonNetwork =
          await trust1.process(FollowNode(signInState.center), 1);
      assert(trust1.rejected.isEmpty);
      // This network doesn't have equivalent keys whereas oneofusNet.network does, and add them here.
      List<String> tmp = <String>[];
      for (String canon in canonNetwork.keys) {
        tmp.addAll(oneofusEquiv.getEquivalents(canon));
      }
      network = tmp;
    } else {
      network = oneofusNet.network.keys;
    }

    Map<String, String?> delegate2revokeAt = <String, String?>{};
    for (String oneofusKey in network) {
      Fetcher oneofusFetcher = Fetcher(oneofusKey, kOneofusDomain);
      assert(oneofusFetcher.isCached);
      for (TrustStatement s in distinct(oneofusFetcher.statements)
          .cast<TrustStatement>()
          .where((s) => s.verb == TrustVerb.delegate)) {
        String delegateToken = s.subjectToken;
        delegate2revokeAt[delegateToken] = s.revokeAt;
        // Keep track of who's delegate this is for naming delegates (as in, 'homer-nerdster.org')
        // Equivalents (or even unrelated) may claim the same delegate; I'm going with the first claim (for now)
        String oneofus = oneofusEquiv.getCanonical(oneofusKey);
        if (!_delegate2oneofus.containsKey(delegateToken)) {
          _delegate2oneofus[delegateToken] = oneofus;
        }
        _oneofus2delegates.putIfAbsent(oneofus, () => <String>{}).add(delegateToken);
      }
    }

    for (MapEntry<String, String?> e in delegate2revokeAt.entries) {
      String delegateToken = e.key;
      String? revokeAt = e.value;
      Fetcher fetcher = Fetcher(delegateToken, kNerdsterDomain);
      if (b(revokeAt)) fetcher.setRevokeAt(revokeAt!);
      await fetcher.fetch(); // fill cache, query revokeAtTime
      assert(fetcher.revokeAt == null || fetcher.revokeAtTime != null);
      _delegate2fetcher[delegateToken] = fetcher;
    }

    // load up Most in case we didn't run our search that does it.
    if (!b(fcontext)) {
      for (ContentStatement s in (_delegate2fetcher.values)
          .map((f) => distinct(f.statements))
          .flattened
          .cast<ContentStatement>()
          .where((s) => s.verb == ContentVerb.follow)) {
        _mostContexts.process(s.contexts!.keys);
      }
    }

    BarRefresh.elapsed(runtimeType.toString());
  }

  void _processFollowStatementForMost(ContentStatement c) {
    _mostContexts.process(c.contexts!.keys);
  }
}

// We're building the follow network on top of OneofusNet and EquivNet.
// Unlike [_FetcherNode], we do cache (no revoking discovered during search).
class FollowNode extends Node {
  static final Map<String, FollowNode> _factoryCache = {};

  static void clear() {
    _factoryCache.clear();
  }

  factory FollowNode(String token) {
    if (!_factoryCache.containsKey(token)) {
      _factoryCache[token] = FollowNode._internal(token);
    }
    return _factoryCache[token]!;
  }

  FollowNode._internal(super.token);

  bool processed = false;
  final List<Trust> _trusts = <Trust>[];
  final List<Block> _blocks = <Block>[];

  Future<void> process() async {
    if (processed) return;
    assert(Comp.compsReady([oneofusNet, oneofusEquiv]));

    List<Iterable<Statement>> delegateStatementss = <Iterable<Statement>>[];
    for (String equiv in oneofusEquiv.getEquivalents(token)) {
      Fetcher oneofusFetcher = Fetcher(equiv, kOneofusDomain);
      assert(oneofusFetcher.isCached);
      for (TrustStatement delegateStatement in distinct(oneofusFetcher.statements)
          .cast<TrustStatement>()
          .where((s) => s.verb == TrustVerb.delegate)) {
        Fetcher delegateFetcher = Fetcher(delegateStatement.subjectToken, kNerdsterDomain);
        await delegateFetcher.fetch();
        delegateStatementss.add(delegateFetcher.statements);
      }
    }
    Merger merger = Merger(delegateStatementss);
    Iterable<ContentStatement> dis =
        distinct(merger.cast(), transformer: oneofusEquiv.getCanonical).cast();
    for (ContentStatement followStatement in dis.where((s) => s.verb == ContentVerb.follow)) {
      if (!oneofusNet.network.containsKey(followStatement.subjectToken)) continue; // not Oneofus
      followNet._processFollowStatementForMost(followStatement);
      String canon = oneofusEquiv.getCanonical(followStatement.subjectToken);
      assert(oneofusNet.network.containsKey(canon));
      // Use context to compute {follow, blocking, or neither} for this nerd.
      Json contexts = followStatement.contexts!;
      int? i = contexts[followNet.fcontext];
      if (b(i)) {
        if (i! > 0) {
          _trusts.add(Trust(FollowNode(canon), followStatement.time, followStatement.token));
        } else {
          _blocks.add(Block(FollowNode(canon), followStatement.time, followStatement.token));
        }
      }
    }
    processed = true;
  }

  @override
  Future<Iterable<Trust>> get trusts async {
    await process();
    return _trusts;
  }

  Iterable<Trust> get cachedTrusts {
    assert(processed);
    return _trusts;
  }

  @override
  Future<Iterable<Block>> get blocks async {
    await process();
    return _blocks;
  }

  Iterable<Block> get cachedBlocks {
    assert(processed);
    return _blocks;
  }

  @override
  Future<Iterable<Replace>> get replaces async => [];

  @override
  set revokeAt(String? revokeAt) => throw Exception('unexpected');
  @override
  String? get revokeAt => null;
  @override
  DateTime? get revokeAtTime => null;
}
