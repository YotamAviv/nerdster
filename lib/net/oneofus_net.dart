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
    _readParams();
    signInState.addListener(listen);
  }

  int _degrees = 6;
  int _numPaths = 1;
  int _blockerBenefit = 1;
  LinkedHashMap<String, Node> _network = LinkedHashMap<String, Node>();
  final Map<String, int> _token2keyCounter = <String, int>{};
  final Map<String, String> _rejected = <String, String>{};

  int? getPosition(token) => _token2keyCounter[token];

  void _readParams() {
    Map<String, String> params = Uri.base.queryParameters;
    String? degreesParam = params['degrees'];
    if (b(degreesParam)) {
      try {
        degrees = int.parse(degreesParam!);
        print('degrees=$degrees');
      } catch (e) {
        print(e);
      }
    }

  }

  void setParams(Map<String, String> params) {
    params['degrees'] = degrees.toString();
  }

  int get degrees => _degrees;
  set degrees(int degrees) {
    _degrees = degrees;
    listen();
  }

  int get numPaths => _numPaths;
  set numPaths(int numPaths) {
    _numPaths = numPaths;
    listen();
  }

  int get blockerBenefit => _blockerBenefit;
  set blockerBenefit(int blockerBenefit) {
    _blockerBenefit = blockerBenefit;
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

    // No need to clear Fetcher content, just clear all Fetcher revokedAt values.
    Fetcher.resetRevokedAt();
    NetNode.clear();

    // TODO: Make rejected be a return value of the algorithm.
    _rejected.clear();

    // (Formerly TrustBridge)
    Trust1 trust1 = Trust1(degrees: _degrees, numPaths: _numPaths, blockerBenefit: _blockerBenefit);
    FetcherNode.clear();
    _network = await trust1.process(FetcherNode(signInState.center));

    _rejected.addAll(trust1.rejected);
    _token2keyCounter.clear();

    int keyCounter = 0;
    for (String token in OneofusNet().network.keys) {
      _token2keyCounter[token] = keyCounter++;
    }

    BarRefresh.elapsed(runtimeType.toString());
  }
}

class FetcherNode extends Node {
  static final Map<String, FetcherNode> _factoryCache = {};
  static void clear() {
    _factoryCache.clear();
  }

  factory FetcherNode(String token) {
    if (!_factoryCache.containsKey(token)) {
      _factoryCache[token] = FetcherNode._internal(token);
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
    await _fetcher.fetch(); // (redundant, but okay; should already be fetched at get blocks)
    return distinct(_fetcher.statements)
        .cast()
        .where((s) => s.verb == TrustVerb.trust)
        .map((s) => Trust(FetcherNode(s.subjectToken), s.time, s.token));
  }

  @override
  Future<Iterable<Replace>> get replaces async {
    assert(!blocked);
    await _fetcher.fetch(); // (redundant, but okay; should already be fetched at get blocks)
    return distinct(_fetcher.statements)
        .cast()
        .where((s) => s.verb == TrustVerb.replace)
        .map((s) => Replace(FetcherNode(s.subjectToken), s.time, s.revokeAt, s.token));
  }

  @override
  Future<Iterable<Block>> get blocks async {
    assert(!blocked);
    await _fetcher.fetch();

    return distinct(_fetcher.statements)
        .cast()
        .where((s) => s.verb == TrustVerb.block)
        .map((s) => Block(FetcherNode(s.subjectToken), s.time, s.token));
    // List<Block> blocks = <Block>[];
    // for (TrustStatement statement
    //     in distinct(_fetcher.statements).cast<TrustStatement>().where((s) => s.verb == TrustVerb.block)) {
    //   blocks.add(Block(FetcherNode(statement.subjectToken), statement.time, statement.token));
    // }
    // return blocks;
  }

  FetcherNode._internal(super.token) : _fetcher = Fetcher(token, kOneofusDomain);
}
