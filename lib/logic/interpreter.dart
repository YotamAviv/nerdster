import 'package:nerdster/ui/json_display.dart';
import 'package:intl/intl.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';
import 'package:nerdster/logic/labeler.dart';

const kUnknown = '<unknown>';

class NerdsterInterpreter implements Interpreter {
  final Labeler labeler;

  NerdsterInterpreter(this.labeler);

  @override
  Future<void> waitUntilReady() async {
    // Labeler is synchronous for now, or already ready when passed here.
    return;
  }

  // Label, convert, strip:
  // - "gibberish" (crypto keys, tokens, ['signature', 'previous'] stripped)
  // - datetimes.,
  // - lists and maps of those above
  @override
  dynamic interpret(dynamic d) {
    if (d is Jsonish) {
      return interpret(d.json);
    } else if (d is Statement) {
      return interpret(d.json);
    } else if (d is Iterable) {
      return List.of(d.map(interpret)); // Json converter doesn't like Iterable, and so List.of
    } else if (d is Json && d['crv'] == 'Ed25519') {
      try {
        String token = getToken(d);
        return labeler.hasLabel(token) ? labeler.getLabel(token) : kUnknown;
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
      if (labeler.hasLabel(d)) return labeler.getLabel(d);
      if (RegExp(r'^[0-9a-f]{40}$').hasMatch(d)) {
        return '<crypto token>';
      }
      try {
        return DateFormat.yMd().add_jm().format(DateTime.parse(d).toLocal());
      } catch (e) {
        return d;
      }
    } else if (d is DateTime) {
      return DateFormat.yMd().add_jm().format(d.toLocal());
    } else {
      return d;
    }
  }
}
