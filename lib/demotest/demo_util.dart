import 'dart:convert';

import 'package:json_diff/json_diff.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/net/key_lables.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

// CODE: Rename to test_util

/// I admit that I'm confused as to why I need this.
dynamic toJson(dynamic d) => jsonDecode(jsonEncode(d));

Future<void> signIn(center, delegateKeyPair) async {
  if (!b(delegateKeyPair)) {
    signInState.center = center;
  } else {
    // await _sign.centerAndSignIn(center, delegateKeyPair);
    signInState.center = center;
    await signInState.signIn(delegateKeyPair);
  }
  // When I remove this and change the tests, might be nice to have the things that need ready 
  // wait for it.
  
  await Comp.waitOnComps([oneofusEquiv, keyLabels]);
}

/// Weak!
/// I moved code from tests to demos so that I can use the UI on the cases.
/// I'm faking the test infrastructure's expect, but not well;)
myExpect(dynamic actual, dynamic matcher) {
  assert(actual == matcher, '$actual != $matcher');
}

jsonShowExpect(actual, expected) {
  final actual2 = KeyLabels().show(actual);
  final expected2 = KeyLabels().show(expected);
  JsonDiffer differ = JsonDiffer.fromJson(actual2, expected2);
  DiffNode diffNode = differ.diff();
  if (!diffNode.hasNothing) {
    print('diff:\n${differ.diff()}\n');
    print('actual:\n${encoder.convert(actual2)}\n');
    print('expected:\n${encoder.convert(expected2)}\n');
  }
  // Tests used to use: expect(diffNode.hasNothing, true);
  assert(diffNode.hasNothing);
}

jsonExpect(Json actual, Json expected) {
  JsonDiffer differ = JsonDiffer.fromJson(actual, expected);
  DiffNode diffNode = differ.diff();
  if (!diffNode.hasNothing) {
    print('diff:\n${differ.diff()}\n');
    print('actual:\n${encoder.convert(actual)}\n');
    print('expected:\n${encoder.convert(expected)}\n');
  }
  // Tests used to use: expect(diffNode.hasNothing, true);
  assert(diffNode.hasNothing);
}

