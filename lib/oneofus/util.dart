import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import 'crypto/crypto.dart';
import 'crypto/crypto2559.dart';
import 'jsonish.dart';

final DateTime date0 = DateTime.fromMicrosecondsSinceEpoch(0);
const String kSinceAlways = '<since always>';

// TODO: Try to use in more places, have more dialogs look the same.
const kPadding = EdgeInsets.all(4);
const kTallPadding = EdgeInsets.fromLTRB(0, 8, 0, 4);
final BorderRadius kBorderRadius = BorderRadius.circular(8);


const OouCryptoFactory crypto = CryptoFactoryEd25519();
const JsonEncoder encoder = JsonEncoder.withIndent('  ');

// Don't evaluate message if condtion is true.
// I've flipped on this. I like the stack trace and other advantages of the built-in assert.
// void xssert(bool condition, [dynamic messageOrFunc = 'assert failed']) {
//   if (!condition) {
//     String message;
//     if (messageOrFunc == null) {
//       message = '<null>';
//     } else if (messageOrFunc is Function) {
//       message = messageOrFunc();
//     } else {
//       message = messageOrFunc.toString();
//     }
//     print(message);
//     throw Exception(message);
//   }
// }

int countNonNull(dynamic d) => d == null ? 0 : 1;
bool b(dynamic d) => d == null ? false : true;
bool bb(bool? bb) => bb != null && bb;
bool bs(String? s) => (s == null) ? false : s == true.toString();
bool match(String? actual, String expected) => b(actual) && actual! == expected;

abstract class Clock {
  DateTime get now;
  String get nowIso => formatIso(now);
}

class LiveClock extends Clock {
  @override
  DateTime get now => DateTime.now();
}

void useClock(Clock use) {
  clock = use;
}

// Global
Clock clock = LiveClock();

DateTime parseIso(String iso) => DateTime.parse(iso);

final DateFormat datetimeFormat = DateFormat.yMd().add_jm();

// I used to strip off the milliseconds, but that caused a bug where
// statements with the same 'time' were received out of order.
String formatIso(DateTime datetime) {
  return datetime.toUtc().toIso8601String();
}

// KLUDGE: Tests were failing in different time zones, especially those where statements were saved.
// This is still not good as the kludge is probably currently checked in and will only work in EST.
int timezoneOffsetKludge = 0;
String formatUiDatetime(DateTime datetime) {
  DateTime datetime2 = datetime;
  if (timezoneOffsetKludge != 0) {
    datetime2 = datetime.add(Duration(hours: timezoneOffsetKludge));
  }
  return datetimeFormat.format(datetime2.toLocal());
}

String formatUiDate(DateTime datetime) {
  DateFormat dateFormat = DateFormat.yMd();
  return dateFormat.format(datetime.toLocal());
}

// Parses back and forth to check, fix, and make sure (or fix) if it's a private key pair
Future<Json> parsePublicKey(String s) async {
  Json json = jsonDecode(s);
  OouPublicKey publictKey = await crypto.parsePublicKey(json);
  json = await publictKey.json;
  return json;
}
