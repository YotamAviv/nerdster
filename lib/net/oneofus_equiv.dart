import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/equivalence/equate_statement.dart';
import 'package:nerdster/equivalence/wot_equivalence.dart';
import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/distincter.dart';
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

  // interface
  String getCanonical(token) => _equivalence!.getCanonical(token);
  Set<String> getEquivalents(token) => _equivalence!.getEquivalents(token);

  void listen() {
    setDirty();
    notifyListeners();
  }

  @override
  Future<void> process() async {
    thowIfSupportersNotReady();
    measure.start();

    _equivalence = WotEquivalence(Set.of(oneofusNet.network.keys));
    NerdEquateParser equateParser = NerdEquateParser();
    for (String token in oneofusNet.network.keys) {
      for (TrustStatement statement in distinct(Fetcher(token, kOneofusDomain).statements).cast<TrustStatement>()) {
        if (NotificationsMenu.rejected.containsKey(statement.token)) continue;
        EquateStatement? es = equateParser.parse(statement);
        if (es != null) {
          String? rejection = _equivalence!.process(es);
          if (b(rejection)) {
            NotificationsMenu.reject(statement.token, rejection!);
          }
        }
      }
    }
    _equivalence!.make();
    assert(_equivalence!.getCanonical(signInState.center) == signInState.center);

    for (TrustStatement trustStatement
        in distinct(Fetcher(signInState.center, kOneofusDomain).statements)
            .cast<TrustStatement>()) {
      if (trustStatement.verb == TrustVerb.trust) {
        String subjectToken = trustStatement.subjectToken;
        if (getCanonical(subjectToken) != subjectToken) {
          assert(!NotificationsMenu.rejected.containsKey(subjectToken), 'might need multiple');
          NotificationsMenu.warn(trustStatement.token, 'You trust a non-canonical key directly.');
        }
      }
    }

    measure.stop();
  }
}
