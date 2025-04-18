import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/equivalence/equate_statement.dart';
import 'package:nerdster/equivalence/wot_equivalence.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

import '../oneofus/measure.dart';

class OneofusEquiv with Comp, ChangeNotifier {
  static final OneofusEquiv _singleton = OneofusEquiv._internal();
  static final Measure measure = Measure('OneofusEquiv');
  factory OneofusEquiv() => _singleton;

  OneofusEquiv._internal() {
    // supporters
    addSupporter(oneofusNet);
    oneofusNet.addListener(listen);
  }

  // vars
  WotEquivalence? _equivalence;
  final Map<String, Set<String>> _oneofus2delegates = <String, Set<String>>{};
  final Map<String, String> _delegate2oneofus = <String, String>{};
  final Map<String, String?> _delegate2revokeAt = <String, String?>{};

  // interface
  String getCanonical(token) => _equivalence!.getCanonical(token);
  Set<String> getEquivalents(token) => _equivalence!.getEquivalents(token);
  Map<String, Set<String>> get oneofus2delegates => UnmodifiableMapView(_oneofus2delegates);
  Map<String, String> get delegate2oneofus => UnmodifiableMapView(_delegate2oneofus);
  Map<String, String?> get delegate2revokeAt => UnmodifiableMapView(_delegate2revokeAt);

  void listen() {
    setDirty();
    notifyListeners();
  }

  @override
  Future<void> process() async {
    throwIfSupportersNotReady();
    measure.start();

    _equivalence = WotEquivalence(Set.of(oneofusNet.network.keys));
    NerdEquateParser equateParser = NerdEquateParser();
    for (String token in oneofusNet.network.keys) {
      for (TrustStatement statement
          in (Fetcher(token, kOneofusDomain).statements).cast<TrustStatement>()) {
        if (notifications.rejected.containsKey(statement.token)) continue;
        EquateStatement? es = equateParser.parse(statement);
        if (es != null) {
          String? rejection = _equivalence!.process(es);
          if (b(rejection)) {
            notifications.reject(statement.token, rejection!);
          }
        }
      }
    }
    _equivalence!.make();
    assert(_equivalence!.getCanonical(signInState.center) == signInState.center);

    for (TrustStatement trustStatement
        in (Fetcher(signInState.center, kOneofusDomain).statements).cast<TrustStatement>()) {
      if (trustStatement.verb == TrustVerb.trust) {
        String subjectToken = trustStatement.subjectToken;
        if (getCanonical(subjectToken) != subjectToken) {
          assert(!notifications.rejected.containsKey(subjectToken), 'might need multiple');
          notifications.warn(trustStatement.token, 'You trust a non-canonical key directly.');
        }
      }
    }

    _oneofus2delegates.clear();
    _delegate2oneofus.clear();
    _delegate2revokeAt.clear();
    for (final String oneofusKey in oneofusNet.network.keys) {
      Fetcher oneofusFetcher = Fetcher(oneofusKey, kOneofusDomain);
      assert(oneofusFetcher.isCached);
      final String oneofusCanonicalKey = oneofusEquiv.getCanonical(oneofusKey);
      _oneofus2delegates.putIfAbsent(oneofusCanonicalKey, () => <String>{});
      for (TrustStatement s in oneofusFetcher.statements
          .cast<TrustStatement>()
          .where((s) => s.verb == TrustVerb.delegate)) {
        String delegateToken = s.subjectToken;
        // Keep track of who's delegate this is for naming delegates (as in, 'homer-nerdster.org')
        // OLD: Equivalents (or even unrelated) may claim the same delegate
        // NEW: A delegate can be only one persons, even if equivalent
        if (!_delegate2oneofus.containsKey(delegateToken)) {
          _delegate2revokeAt[delegateToken] = s.revokeAt;
          _delegate2oneofus[delegateToken] = oneofusCanonicalKey;
          _oneofus2delegates[oneofusCanonicalKey]!.add(delegateToken);
        } else {
          notifications.reject(s.token, 'Delegate already claimed.');
        }
      }
    }

    measure.stop();
  }
}
