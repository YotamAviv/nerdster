import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/net/net_node.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';
import 'package:nerdster/trust/trust1.dart';

/// - OneofusNet (_process)
///  - provides:
///    - rejected statements
///
/// - WotEquivalence
///   - depends on:
///     - OneofusNet
///
/// - DelegateNet
///   - depends on:
///     - OneofusNet
///
/// - TrustNonCanonical
///   - depends on:
///     - WotEquivalence
///
/// - ContentBase (somewhere around here)
///
/// - tree'ish things?
///
/// - KeyLabels
///   - depends on:
///     - DelegateNet

class OneofusNet with Comp, ChangeNotifier {
  static final OneofusNet _singleton = OneofusNet._internal();
  factory OneofusNet() => _singleton;
  OneofusNet._internal() {
    signInState.addListener(listen);
  }

  int _numPaths = 1;
  LinkedHashMap<String, Node> _network = LinkedHashMap<String, Node>();
  final Map<String, int> _token2keyCounter = <String, int>{};
  final Map<String, String> _rejected = <String, String>{};

  int? getPosition(token) => _token2keyCounter[token];

  int get numPaths => _numPaths;
  set numPaths(int numPaths) {
    _numPaths = numPaths;
    listen();
  }

  LinkedHashMap<String, Node> get network => _network;

  Map<String, String> get rejected => UnmodifiableMapView(_rejected);
  void addWotEquivRejected(String statementToken, String reason) {
    if (!_rejected.containsKey(statementToken)) {
      _rejected[statementToken] = reason;
    }
  }

  void listen() {
    if (!ready) {
      // return;
    }
    setDirty();
    notifyListeners();
  }

  @override
  Future<void> process() async {
    Fetcher.clear();
    clearDistinct();
    NetNode.clear();
    _rejected.clear();

    // (Formerly TrustBridge)
    Trust1 trust1 = Trust1();
    _FetcherNode.clear();
    _network = await trust1.process(_FetcherNode(signInState.center), _numPaths);

    _rejected.addAll(trust1.rejected);
    _token2keyCounter.clear();

    int keyCounter = 0;
    for (String token in OneofusNet().network.keys) {
      _token2keyCounter[token] = keyCounter++;
    }

    BarRefresh.elapsed(runtimeType.toString());
  }
}

class _FetcherNode extends Node {
  static final Map<String, _FetcherNode> _factoryCache = {};
  static void clear() {
    _factoryCache.clear();
  }
  factory _FetcherNode(String token) {
    if (!_factoryCache.containsKey(token)) {
      _factoryCache[token] = _FetcherNode._internal(token);
    }
    return _factoryCache[token]!;
  }
  final Fetcher _fetcher;

  @override
  set blocked(bool b) {
    assert(b); // I don't think we ever unblock.
    super.blocked = b;
  }

  @override
  set revokeAt(String? revokeAt) {
    assert(b(revokeAt)); // 'String' not allowed; had to use 'String?' to compile.
    _fetcher.setRevokeAt(revokeAt!);
  }
  @override
  String? get revokeAt => _fetcher.revokeAt;
  @override
  DateTime? get revokeAtTime => _fetcher.revokeAtTime;

  @override
  // We don't cache because _fetcher could be revoked
  // DEFER: MINOR: Listen to _fetcher and cache, minor becuase Fetcher caches.
  Future<Iterable<Trust>> get trusts async {
    assert(!blocked);
    return distinct(_fetcher.statements)
        .cast()
        .where((s) => s.verb == TrustVerb.trust)
        .map((s) => Trust(_FetcherNode(s.subjectToken), s.time, s.token));
  }

  @override
  Future<Iterable<Replace>> get replaces async {
    assert(!blocked);
    return distinct(_fetcher.statements)
        .cast()
        .where((s) => s.verb == TrustVerb.replace)
        .map((s) => Replace(_FetcherNode(s.subjectToken), s.time, s.revokeAt, s.token));
  }

  @override
  Future<Iterable<Block>> get blocks async {
    assert(!blocked);
    await _fetcher.fetch();

    return distinct(_fetcher.statements)
        .cast()
        .where((s) => s.verb == TrustVerb.block)
        .map((s) => Block(_FetcherNode(s.subjectToken), s.time, s.token));
    // List<Block> blocks = <Block>[];
    // for (TrustStatement statement
    //     in _fetcher.statements.cast().where((s) => s.verb == TrustVerb.block)) {
    //   blocks.add(Block(_FetcherNode(statement.subjectToken), statement.time, statement.token));
    // }
    // return blocks;
  }

  _FetcherNode._internal(super.token) : _fetcher = Fetcher(token, kOneofusDomain);
}
