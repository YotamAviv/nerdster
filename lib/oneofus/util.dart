import 'dart:convert';

import 'package:intl/intl.dart';

import 'crypto/crypto.dart';
import 'crypto/crypto2559.dart';
import 'jsonish.dart';

const OouCryptoFactory crypto = CryptoFactoryEd25519();
const JsonEncoder encoder = JsonEncoder.withIndent('  ');

int i(dynamic d) => d == null ? 0 : 1;
bool b(dynamic d) => d == null ? false : true;
bool bb(bool? bb) => (bb == null) ? false : bb;
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

