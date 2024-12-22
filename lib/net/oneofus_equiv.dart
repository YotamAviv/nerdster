import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/equivalence/equate_statement.dart';
import 'package:nerdster/equivalence/wot_equivalence.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

/// Notifications: Conflicts, Rejected statements, oh my..
/// All possible examples:
/// - You trust non-canonical key directly
/// - Rejected statements:
///   - block rejected by Trust algorith: from farther than allowed (in relation to who's being blocked/replaced).
///   - replace rejected by Trust algorith: can't replace a replaced key.
///   - equivalence rejected by WotEquivalence.
/// - DEFER: Blockchain violations. These should render the entire key corrupted.

///
/// New rule: You can only revoke an equivalent key.
/// Formerly, I had planned to show a revocation of key by another keynot in its own EG.
/// Now I don't see the use case for allowing that in the first place.

/// New rule: Only a canonical key can state that another is its equivalent.
/// (NOTE: There is no dontEquate for Oneofus trust.)
/// Rational:
/// - WebOfTrust
/// - If you have the key, you can do it.
/// - If you've lost your key, then get another key and do it with your new (now canonical) key.
/// - (So: No "otherSubject" for one-of-us.net.)

/// New rule: monikers on other keys only with trust statement (trust, block, revoke, equate, delegate, clear).
/// - "This is the key from my lost iPad". Sure, why not..
/// I don't think that I want a discussion forum (comments about comments about nerds) here just yet.

class OneofusEquiv with Comp, ChangeNotifier {
  static final OneofusEquiv _singleton = OneofusEquiv._internal();
  factory OneofusEquiv() => _singleton;
  OneofusEquiv._internal() {
    // supporters
    addSupporter(oneofusNet);
    oneofusNet.addListener(listen);

    // CODE: This class listens to these prefs, but that seems to be only to make something
    // that listens to us dirty when they change. TODO3: Clean up.
    Prefs.showKeys.addListener(listen);
    Prefs.showStatements.addListener(listen);
  }

  // vars
  WotEquivalence? _equivalence;
  final Map<String, String> _trustNonCanonical = <String, String>{};

  // interface
  String getCanonical(token) => _equivalence!.getCanonical(token);
  Set<String> getEquivalents(token) => _equivalence!.getEquivalents(token);
  Map<String, String> get trustNonCanonical => UnmodifiableMapView(_trustNonCanonical);

  void listen() {
    setDirty();
    notifyListeners();
  }

  @override
  Future<void> process() async {
    assert(Comp.compsReady([oneofusNet]));
    _equivalence = WotEquivalence(Set.of(oneofusNet.network.keys));
    NerdEquateParser equateParser = NerdEquateParser();
    for (String token in oneofusNet.network.keys) {
      for (TrustStatement statement in distinct(Fetcher(token, kOneofusDomain).statements).cast()) {
        if (oneofusNet.rejected.containsKey(statement.token)) {
          continue;
        }
        EquateStatement? es = equateParser.parse(statement);
        if (es != null) {
          bool accepted = _equivalence!.process(es);
          if (!accepted) {
            oneofusNet.addWotEquivRejected(
                statement.token, 'web-of-trust key equivalence rejected');
          }
        }
      }
    }
    _equivalence!.make();
    assert(_equivalence!.getCanonical(signInState.center) == signInState.center);

    _trustNonCanonical.clear();
    for (TrustStatement trustStatement
        in distinct(Fetcher(signInState.center, kOneofusDomain).statements)
            .cast<TrustStatement>()) {
      if (trustStatement.verb == TrustVerb.trust) {
        String subjectToken = trustStatement.subjectToken;
        if (getCanonical(subjectToken) != subjectToken) {
          assert(!oneofusNet.rejected.containsKey(subjectToken), 'might need multiple');
          _trustNonCanonical[trustStatement.token] = 'You trust a non-canonical key directly.';
        }
      }
    }

    BarRefresh.elapsed(runtimeType.toString());
  }
}
