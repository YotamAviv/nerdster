import 'dart:convert';

import 'package:json_diff/json_diff.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/interpreter.dart';

// CODE: Rename to test_util

/// I admit that I'm confused as to why I need this.
dynamic toJson(dynamic d) => jsonDecode(jsonEncode(d));

/// Weak!
/// I moved code from tests to demos so that I can use the UI on the cases.
/// I'm faking the test infrastructure's expect, but not well;)
void myExpect(dynamic actual, dynamic matcher) {
  assert(actual == matcher, '$actual != $matcher');
}

void jsonShowExpect(dynamic actual, dynamic expected) {
  final interpreter = null; // TODO: Pass interpreter
  final actual2 = interpreter != null ? interpreter.interpret(actual) : actual;
  final expected2 = interpreter != null ? interpreter.interpret(expected) : expected;
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

void jsonExpect(Json actual, Json expected) {
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

