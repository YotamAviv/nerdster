import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

// TODO: CODE: Something like this
enum KString {
  blockYourKey('Attempt to block your key.'),
  replaceYourKey('Attempt to replace your key.'),
  //
  blockTrustedKey('Attempt to block trusted key.'),
  replaceTrustedKey('Attempt to replace trusted key.'),
  replaceReplacedKey('Attempt to replace a replaced key.'),
  trustBlockedKey('Attempt to trust blocked key.'),
  //
  delegateAlreadyClaimed('Delegate already claimed.');

  const KString(this.label);
  final String label;
}

// Goal: Test every kind of rejection / notification.
// - Attempt to block your key.
// - Attempt to replace your key.
// - Attempt to block trusted key.
// - Attempt to trust blocked key.
// - Attempt to replace a replaced key.
// - Attempt to replace trusted key. TODO:
// - You trust a non-canonical key directly. TODO:
// - Delegate already claimed.
// - DEFER: Attempt to replace a blocked key.
// - Web-of-trust key equivalence rejected: Replaced key not in network. ('simpsons, degrees=2')
// - TO-DO: Web-of-trust key equivalence rejected: Replacing key not in network.
//   I don't think this can happen, not sure.. CONSIDER
// - TO-DO: Web-of-trust key equivalence rejected: Equivalent key already replaced.
//   I don't think this can happen, not sure.. CONSIDER

// Notifications started out with Strings, then Map<String, String>, then Map<String,
// (String, String)> with test proceeding.
// A cleanup phase separating model from view led to [Problem], but other stuff was left behind to
// save rewriting the tests.
class Problem {}

class TrustProblem extends Problem {
  final String statementToken;
  final String problem;

  TrustProblem({required this.statementToken, required this.problem});
}

class CorruptionProblem extends Problem {
  final String keyToken;
  final String error;
  final String? details;

  CorruptionProblem({required this.keyToken, required this.error, this.details});
}

/// Place where problems encoutered during OneofusNet process are collected (Fetcher corruption,
/// GreedyBfsTrust conflicts, equivalence conflicts, I'm not even sure..)
class BaseProblemCollector with ChangeNotifier implements CorruptionProblemCollector {
  static final BaseProblemCollector singleton = BaseProblemCollector._internal();
  factory BaseProblemCollector() => singleton;
  BaseProblemCollector._internal();

  final LinkedHashMap<String, String> _rejected = LinkedHashMap<String, String>();
  final LinkedHashMap<String, String> _warned = LinkedHashMap<String, String>();
  final LinkedHashMap<String, CorruptionProblem> _corrupted =
      LinkedHashMap<String, CorruptionProblem>();

  // Where/when to call this isn't clear, probably OneofusNet.process, some tests, too.
  void clear() {
    _rejected.clear();
    _warned.clear();
    _corrupted.clear();
  }

  Map<String, String> get rejected => UnmodifiableMapView(_rejected);
  Iterable<Problem> get rejectedProblems =>
      rejected.entries.map((e) => TrustProblem(statementToken: e.key, problem: e.value));
  void reject(String token, String problem) {
    assert(Jsonish.find(token) != null);
    _rejected[token] = problem;
    notifyListeners();
  }

  Map<String, String> get warned => UnmodifiableMapView(_warned);
  Iterable<Problem> get warnedProblems =>
      warned.entries.map((e) => TrustProblem(statementToken: e.key, problem: e.value));
  void warn(String token, String problem) {
    assert(Jsonish.find(token) != null);
    _warned[token] = problem;
    notifyListeners();
  }

  Map<String, CorruptionProblem> get corrupted => UnmodifiableMapView(_corrupted);
  @override
  void corrupt(String token, String error, String? details) {
    _corrupted[token] = (CorruptionProblem(keyToken: token, error: error, details: details));
    notifyListeners();
  }
}

final delegateCheck = DelegateCheck();
final identityCheck = IdentityCheck();

class Notifications with Comp, ChangeNotifier {
  static final Notifications _singleton = Notifications._internal();
  factory Notifications() => _singleton;
  Notifications._internal() {
    baseProblemCollector.addListener(listen);
    addSupporter(followNet);
    followNet.addListener(listen);
    addSupporter(delegateCheck);
    delegateCheck.addListener(listen);
    addSupporter(identityCheck);
    identityCheck.addListener(listen);
    addSupporter(oneofusLabels);
    oneofusLabels.addListener(listen);

    setDirty();
    waitUntilReady();
  }

  final List<Problem> _problems = <Problem>[];

  List get problems => UnmodifiableListView(_problems);

  void listen() {
    setDirty();
    notifyListeners();
  }

  @override
  Future<void> process() async {
    _problems.clear();
    if (b(oneofusLabels.problem.value)) _problems.add(oneofusLabels.problem.value!);
    if (b(identityCheck.problem.value)) _problems.add(identityCheck.problem.value!);
    if (b(delegateCheck.problem.value)) _problems.add(delegateCheck.problem.value!);
    _problems.addAll(baseProblemCollector.rejectedProblems);
    _problems.addAll(baseProblemCollector.warnedProblems);
    _problems.addAll(baseProblemCollector.corrupted.values);
  }
}

class TitleDescProblem implements Problem {
  final String title;
  final String? desc;

  TitleDescProblem({required this.title, this.desc});

  @override
  String toString() => '$title:$desc';
}

class IdentityCheck with Comp, ChangeNotifier {
  static final IdentityCheck _singleton = IdentityCheck._internal();
  factory IdentityCheck() => _singleton;

  final ValueNotifier<TitleDescProblem?> problem = ValueNotifier(null);

  IdentityCheck._internal() {
    addSupporter(followNet);
    followNet.addListener(listen);
  }

  void listen() {
    setDirty();
    notifyListeners();
  }

  @override
  Future<void> process() async {
    problem.value = null;
    if (b(signInState.centerReset) &&
        !followNet.oneofus2delegates.containsKey(signInState.centerReset)) {
      problem.value = TitleDescProblem(
          title: '''You're not in this network''',
          desc:
              '''You signed in using an identity that isn't currently a member of the network you're viewing.
Your own contributions are not be visible from this PoV (Point of View).
You can still rate, submit, change follow settings, etc..., and those changes will be visible when you use a PoV that includes you.''');
    }
  }
}

class DelegateCheck with Comp, ChangeNotifier {
  static final DelegateCheck _singleton = DelegateCheck._internal();
  factory DelegateCheck() => _singleton;

  final ValueNotifier<TitleDescProblem?> problem = ValueNotifier(null);

  DelegateCheck._internal() {
    addSupporter(myDelegateStatements);
    myDelegateStatements.addListener(listen);
  }

  void listen() {
    setDirty();
    notifyListeners();
  }

  @override
  Future<void> process() async {
    assert(myDelegateStatements.ready);

    if (!b(signInState.signedInDelegate)) {
      problem.value = null;
      return;
    }

    Fetcher fetcher = Fetcher(signInState.centerReset!, kOneofusDomain);
    assert(fetcher.isCached);

    for (TrustStatement s in fetcher.statements.cast<TrustStatement>()) {
      if (s.verb == TrustVerb.delegate &&
          s['with']['domain'] == kNerdsterDomain &&
          s.subjectToken == signInState.signedInDelegate) {
        // delegate is associated with me
        if (s.revokeAt != null) {
          problem.value = TitleDescProblem(title: 'Your Nerdster delegate is revoked');
          return;
        } else {
          problem.value = null;
          return;
        }
      }
    }
    problem.value = TitleDescProblem(
        title: 'Your Nerdster delegate is not associated with your signed in identity');
  }
}
