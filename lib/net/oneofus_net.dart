import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/net/net_node.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/progress.dart';
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

/// Notifications plan (WIP)
///
/// Conflicts, I think these are all "rejections"
/// Trivial: Shoudn't happen, probably a bug. Show them to the user making them. He should clear these mistakes
/// - don't block yourself
/// - don't replace yourself
/// - don't trust yourself
///
/// Trivial'ish: Show you the other key (Yes, both keys in network)
/// - attempt to block your key
/// - attempt to replace your key
///
/// Trust / block conflict: pure conflict, user should figure it out and fix.
/// - rejected trust (trust blocked key) (NEW) (No, key not in network)
/// - rejected block (blocker farther than trustee) (Yes, both keys in network)
///
/// - rejected replace (already replaced key) (Yes, both keys in network)
///   (this is rejected, but it's not necessarily a conflict; it could be that
///    1) your 2'nd key replaces your 1'st
///    2) your 3'rd key replacing your 1'st and 2'nd
///   It is sort of a conflict. Your 2'nd key is not a replacement of your 1'st, now your 3'rd is.
///   It could also be an absolute conflict, someone else (not EG) claims your old key.
///
/// - rejected replace (replacer farther than trustee) (Yes, both keys in network)
///   TODO: CONSIDER: Why reject this?
/// - rejected replace (key already blocked). (No, key not in network)
///   TODO: Think...
///
/// WOT trust non-canonical key directly (note that these are not conflicts or rejections)
///
/// - List all types (attempt to block you, etc...)
///   - maybe there are severities associated with these
///   - write descriptions and remedies
///
///
/// - Dialog showing both keys invovled.
///   (No special case for 'Me'. Anyone should be able to view conflicts centered as anyone)
///   - show distinct trust paths to both keys (Okay, 'Me' is special)
///     - maybe that's 2 different popup dialogs
///     - allow similar popup dialogs along the way of the path, and so maybe show both keys, clicking on key brings up the path and shows the keys along the path

///

class OneofusNet with Comp, ChangeNotifier {
  static final OneofusNet _singleton = OneofusNet._internal();
  static final Measure measure = Measure('OneofusNet');
  factory OneofusNet() => _singleton;
  OneofusNet._internal() {
    signInState.addListener(listen);
    Prefs.oneofusNetDegrees.addListener(listen);
    Prefs.oneofusNetPaths.addListener(listen);
  }

  LinkedHashMap<String, Node> _network = LinkedHashMap<String, Node>();
  final Map<String, int> _token2keyCounter = <String, int>{};
  final LinkedHashMap<String, String> _rejected = LinkedHashMap<String, String>();

  int? getPosition(token) => _token2keyCounter[token];

  int get degrees => Prefs.oneofusNetDegrees.value;
  set degrees(int degrees) {
    Prefs.oneofusNetDegrees.value = degrees;
  }

  int get numPaths => Prefs.oneofusNetPaths.value;
  set numPaths(int numPaths) {
    Prefs.oneofusNetPaths.value = numPaths;
  }

  LinkedHashMap<String, Node> get network => _network;

  Map<String, String> get rejected => UnmodifiableMapView(_rejected);

  void listen() {
    setDirty();
    notifyListeners();
  }

  @override
  Future<void> process() async {
    measure.start();
    
    // No need to clear Fetcher content, just clear all Fetcher revokedAt values.
    Fetcher.resetRevokedAt();
    NetNode.clear();
    FetcherNode.clear();
    Trust1 trust1 = Trust1(degrees: degrees, numPaths: numPaths);
    _network = await trust1.process(FetcherNode(signInState.center));
    _rejected.clear();
    _rejected.addAll(trust1.rejected); // CODE: Make rejected be a return value of the algorithm.
    _token2keyCounter.clear();

    int keyCounter = 0;
    for (String token in network.keys) {
      _token2keyCounter[token] = keyCounter++;
    }

    measure.stop();
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
    await _fetcher.fetch();
    // TODO: moving to cloud distinct...  Not entirely, and not necessarily fully 
    // correctly (other subject..)
    return distinct(_fetcher.statements)
        .cast()
        .where((s) => s.verb == TrustVerb.trust)
        .map((s) => Trust(FetcherNode(s.subjectToken), s.time, s.token));
  }

  @override
  Future<Iterable<Replace>> get replaces async {
    assert(!blocked);
    await _fetcher.fetch();
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
