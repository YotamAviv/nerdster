import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/net/net_node.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/merger.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/greedy_bfs_trust.dart';
import 'package:nerdster/trust/trust.dart';

import '../oneofus/measure.dart';

const kNerdsterContext = '<nerdster>';
const kOneofusContext = '<one-of-us>';
const kSpecialContexts = {kOneofusContext, kNerdsterContext};
typedef StatementFilter = Iterable<Statement> Function(Iterable<Statement>);

class FollowNet with Comp, ChangeNotifier {
  static final FollowNet _singleton = FollowNet._internal();
  static final Measure measure = Measure('FollowNet');
  factory FollowNet() => _singleton;
  FollowNet._internal() {
    _readParams();
    // supporters
    addSupporter(oneofusNet);
    oneofusNet.addListener(listen);
    addSupporter(oneofusEquiv);
    oneofusEquiv.addListener(listen);

    // Prefs
    Prefs.followNetDegrees.addListener(listen);
    Prefs.followNetPaths.addListener(listen);
  }

  void _readParams() {
    _context = Uri.base.queryParameters['follow'] ?? kNerdsterContext;
  }

  void setParams(Map<String, String> params) {
    params['follow'] = _context;
  }

  // vars
  String _context = kNerdsterContext;
  final _MostContexts _mostContexts = _MostContexts();
  final Set<String> _centerContexts = <String>{};
  final Map<String, Set<String>> _oneofus2delegates = <String, Set<String>>{};
  final Map<String, String> _delegate2oneofus = <String, String>{};
  final Map<String, Fetcher> _delegate2fetcher = <String, Fetcher>{};

  // interface
  String get fcontext => _context;
  set fcontext(String context) {
    _context = context;
    listen();
  }

  Iterable<String> get most => _mostContexts.most();
  Set<String> get centerContexts => _centerContexts;

  Map<String, Set<String>> get oneofus2delegates => UnmodifiableMapView(_oneofus2delegates);
  Map<String, String> get delegate2oneofus => UnmodifiableMapView(_delegate2oneofus);
  Map<String, Fetcher> get delegate2fetcher => UnmodifiableMapView(_delegate2fetcher);
  Iterable<ContentStatement> getStatements(String oneofus) {
    assert(oneofusNet.network.containsKey(oneofus),
        "This used to be a bug, but I forgot the details and believe it's fixed.");
    return distinct(
        Merger(_oneofus2delegates[oneofus]!
            .map((delegate) => _delegate2fetcher[delegate]!.statements)).cast<ContentStatement>(),
        transformer: (delegate) => followNet.delegate2oneofus[delegate]!).cast<ContentStatement>();
  }

  // impl
  void listen() {
    setDirty();
    notifyListeners();
  }

  // impl
  @override
  Future<void> process() async {
    throwIfSupportersNotReady();
    measure.start();

    _mostContexts.clear();
    _centerContexts.clear();
    FollowNode.clear();
    _delegate2oneofus.clear();
    _oneofus2delegates.clear();
    _delegate2fetcher.clear();

    Iterable<String> network;
    final int degrees = Prefs.followNetDegrees.value;
    final int numPaths = Prefs.followNetPaths.value;
    if (_context != kOneofusContext) {
      FollowNode.clear();
      GreedyBfsTrust bfsTrust = GreedyBfsTrust(degrees: degrees, numPaths: numPaths);
      LinkedHashMap<String, Node> canonNetwork =
          await bfsTrust.process(FollowNode(signInState.center), progress: progress.nerdster);
      // This network doesn't have equivalent keys whereas oneofusNet.network does, and add them here.
      List<String> tmp = <String>[];
      for (String canon in canonNetwork.keys) {
        tmp.addAll(oneofusEquiv.getEquivalents(canon));
      }
      network = tmp;
    } else {
      // Apply [degrees, numPaths] restrictions to oneofusNet.network.
      // TEST: (I've manually tested this; I'm missing a unit test)
      List<String> networkX = <String>[];
      networkX.add(oneofusNet.network.entries.first.key); // Special case for source (no paths).
      for (MapEntry<String, Node> e in oneofusNet.network.entries.skip(1)) {
        List<List<Trust>> paths = e.value.paths;
        Iterable<List<Trust>> paths2 = paths.where((p) => (p.length <= degrees));
        if (paths2.length >= numPaths) {
          networkX.add(e.key);
        }
      }
      network = networkX;
    }

    Map<String, String?> delegate2revokeAt = <String, String?>{};
    for (String oneofusKey in network) {
      Fetcher oneofusFetcher = Fetcher(oneofusKey, kOneofusDomain);
      assert(oneofusFetcher.isCached);
      String oneofusCanonicalKey = oneofusEquiv.getCanonical(oneofusKey);
      _oneofus2delegates.putIfAbsent(oneofusCanonicalKey, () => <String>{});
      for (TrustStatement s in oneofusFetcher.statements
          .cast<TrustStatement>()
          .where((s) => s.verb == TrustVerb.delegate)) {
        String delegateToken = s.subjectToken;
        delegate2revokeAt[delegateToken] = s.revokeAt;
        // Keep track of who's delegate this is for naming delegates (as in, 'homer-nerdster.org')
        // OLD: Equivalents (or even unrelated) may claim the same delegate
        // NEW: A delegate can be only one persons, even if equivalent
        String oneofus = oneofusEquiv.getCanonical(oneofusKey);
        if (!_delegate2oneofus.containsKey(delegateToken)) {
          _delegate2oneofus[delegateToken] = oneofus;
          _oneofus2delegates[oneofus]!.add(delegateToken);
        } else {
          notifications.reject(s.token, "Delegate already claimed");
        }
      }
    }
    int count = 0;
    for (MapEntry<String, String?> e in delegate2revokeAt.entries) {
      String delegateToken = e.key;
      String? revokeAt = e.value;
      Fetcher fetcher = Fetcher(delegateToken, kNerdsterDomain);
      if (b(revokeAt)) {
        // NOPE: assert(fetcher.revokeAt == revokeAt, 'checking..');
        fetcher.setRevokeAt(revokeAt!);
      }
      // NOPE: assert(fetcher.isCached || _context == kOneofusContext, 'checking..');
      if (_context == kOneofusContext) {
        progress.nerdster.value = count++ / delegate2revokeAt.length;
      }
      await fetcher.fetch(); // fill cache, query revokeAtTime
      assert(fetcher.revokeAt == null || fetcher.revokeAtTime != null);
      _delegate2fetcher[delegateToken] = fetcher;
    }

    // Load up _mostContexts
    for (ContentStatement s in (_delegate2fetcher.values)
        .map((f) => f.statements)
        .flattened
        .cast<ContentStatement>()
        .where((s) => s.verb == ContentVerb.follow)) {
      _mostContexts.process(s.contexts!.keys);
    }

    // Load up _centerContexts.
    Iterable<Iterable<Statement>> delegateStatementss = oneofus2delegates[signInState.center]!
        .map((d) => delegate2fetcher[d]!)
        .map((f) => f.statements);
    Merger merger = Merger(delegateStatementss);
    Iterable<ContentStatement> dis =
        distinct(merger.cast<ContentStatement>()).cast<ContentStatement>();
    for (ContentStatement followStatement in dis.where((s) => s.verb == ContentVerb.follow)) {
      Json followContextsJ = followStatement.contexts!;
      Iterable<String> contexts =
          followContextsJ.entries.where((e) => e.value > 0).map((e) => e.key);
      _centerContexts.addAll(contexts.where((x) => !kSpecialContexts.contains(x)));
    }

    measure.stop();
  }
}

// We're building the follow network on top of OneofusNet and EquivNet.
// Unlike [_FetcherNode], we do cache (no revoking discovered during search). DEFER: REVISIT: greedyBfs no longer revokes during search.
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

  Future<void> _prep() async {
    if (processed) return;
    assert(Comp.compsReady([oneofusNet, oneofusEquiv]));

    List<Iterable<Statement>> delegateStatementss = <Iterable<Statement>>[];
    for (String equiv in oneofusEquiv.getEquivalents(token)) {
      Fetcher oneofusFetcher = Fetcher(equiv, kOneofusDomain);
      if (!oneofusNet.network.containsKey(equiv)) continue; // not Oneofus
      for (TrustStatement delegateStatement in oneofusFetcher.statements
          .cast<TrustStatement>()
          .where((s) => s.verb == TrustVerb.delegate)) {
        Fetcher delegateFetcher = Fetcher(delegateStatement.subjectToken, kNerdsterDomain);
        // NOPE: assert(delegateFetcher.isCached, 'checking..');
        await delegateFetcher.fetch();
        delegateStatementss.add(delegateFetcher.statements);
      }
    }
    Merger merger = Merger(delegateStatementss);
    // QUESTIONABLE:
    // Below is a distinct/merger combo with no transformer.
    // The ContentStatements are presumably stated by ...
    //   the delegates of the equivalents of a single Oneofus key.
    // We're in the process of computing FollowNet, and so we can't use FollowNet.delegate2oneofus.
    // I do think that issues will arise if delegates of the same Oneofus trust/block (in the
    // follow sense) the same dude.
    // TEST: d1 follows x; d2 follows x; d3 blocks x; d4 blocks x. The desired result is probably
    //   just one block
    Iterable<ContentStatement> dis =
        distinct(merger.cast<ContentStatement>()).cast<ContentStatement>();
    for (ContentStatement followStatement in dis.where((s) => s.verb == ContentVerb.follow)) {
      assert(followStatement.verb == ContentVerb.follow);
      if (!oneofusNet.network.containsKey(followStatement.subjectToken)) continue; // not Oneofus
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

    // Default <nerdster> context
    assert(oneofusEquiv.getCanonical(token) == token);
    if (followNet.fcontext == kNerdsterContext) {
      for (TrustStatement ts in NetNode.getCanonicalTrustStatements(token)) {
        assert(oneofusEquiv.getCanonical(ts.iToken) == token);
        if (!oneofusNet.network.containsKey(token)) continue; // not Oneofus
        String canon = oneofusEquiv.getCanonical(ts.subjectToken);
        if (!oneofusNet.network.containsKey(canon)) continue; // not Oneofus
        _trusts.add(Trust(FollowNode(canon), ts.time, ts.token));
      }
    }
    assert(Set.of(oneofusNet.network.keys).containsAll(_trusts.map((t) => t.node.token)));

    processed = true;
  }

  @override
  Future<Iterable<Trust>> get trusts async {
    await _prep();
    return _trusts;
  }

  Iterable<Trust> get cachedTrusts {
    assert(processed);
    return _trusts;
  }

  @override
  Future<Iterable<Block>> get blocks async {
    await _prep();
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

class _MostContexts {
  final Map<String, int> _x2count = <String, int>{};

  void clear() {
    _x2count.clear();
  }

  void process(Iterable<String> xs) {
    for (String x in xs) {
      if (kSpecialContexts.contains(x)) continue;
      if (!_x2count.containsKey(x)) _x2count[x] = 0;
      _x2count[x] = _x2count[x]! + 1;
    }
  }

  Iterable<String> most() {
    Iterable<MapEntry<String, int>> sorted = _x2count.entries.toList()
      ..sort((e1, e2) => e2.value.compareTo(e1.value));
    return sorted.map((e) => e.key);
  }
}
