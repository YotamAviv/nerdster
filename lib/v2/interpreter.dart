import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/labeler.dart';

class V2Interpreter implements Interpreter {
  final V2Labeler labeler;

  V2Interpreter(this.labeler);

  @override
  Future<void> waitUntilReady() async {
    // V2Labeler is synchronous for now, or already ready when passed here.
    return;
  }

  String? _labelKey(String token) {
    String label = labeler.getLabel(token);

    // If the label is just a truncated version of the token,
    // AND the token doesn't look like a crypto token,
    // then it's probably just a random string that got truncated.
    // We should return null to let interpret handle it (e.g. as a date or raw string).
    if (token.length > 8 && label == token.substring(0, 8)) {
      if (RegExp(r'^[0-9a-f]{40}$').hasMatch(token)) {
        return label;
      }
      return null;
    }
    return label;
  }

  @override
  dynamic interpret(dynamic d) {
    if (d is Jsonish) {
      return interpret(d.json);
    } else if (d is Statement) {
      return interpret(d.json);
    } else if (d is Iterable) {
      return List.of(d.map(interpret));
    } else if (d is Json && d['crv'] == 'Ed25519') {
      try {
        String token = getToken(d);
        return b(_labelKey(token)) ? _labelKey(token) : '<unknown>';
      } catch (e) {
        return d;
      }
    } else if (d is Map) {
      List<String> keys = List.of(d.keys.cast<String>())..sort(Jsonish.compareKeys);
      Map out = {};
      for (String key in keys) {
        if (key == 'statement' || key == 'signature' || key == 'previous') continue;
        out[interpret(key)] = interpret(d[key]);
      }
      return out;
    } else if (d is String) {
      String? keyLabel = _labelKey(d);
      if (b(keyLabel)) return keyLabel!;
      if (RegExp(r'^[0-9a-f]{40}$').hasMatch(d)) {
        return '<crypto token>';
      }
      try {
        return formatUiDatetime(parseIso(d));
      } catch (e) {
        return d;
      }
    } else if (d is DateTime) {
      return formatUiDatetime(d);
    } else {
      return d;
    }
  }
}
