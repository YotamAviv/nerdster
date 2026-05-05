import 'package:intl/intl.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/ui/json_display.dart';
import 'package:nerdster_common/labeler.dart';

class JsonInterpreter implements Interpreter {
  final Labeler labeler;
  const JsonInterpreter(this.labeler);

  @override
  dynamic interpret(dynamic d) {
    if (d is Jsonish) return interpret(d.json);
    if (d is Statement) return interpret(d.json);
    if (d is Iterable) return List.of(d.map(interpret));
    if (d is Json && d['crv'] == 'Ed25519') {
      try {
        final token = getToken(d);
        return labeler.hasLabel(token) ? labeler.getLabel(token) : '<crypto key>';
      } catch (e) {
        return d;
      }
    }
    if (d is Map) {
      final keys = List.of(d.keys.cast<String>())..sort(Jsonish.compareKeys);
      final out = <String, dynamic>{};
      for (final key in keys) {
        if (key == 'statement' || key == 'signature' || key == 'previous') continue;
        out[interpret(key)] = interpret(d[key]);
      }
      return out;
    }
    if (d is String) {
      if (labeler.hasLabel(d)) return labeler.getLabel(d);
      if (RegExp(r'^[0-9a-f]{40}$').hasMatch(d)) return '<crypto token>';
      try {
        return DateFormat.yMd().add_jm().format(DateTime.parse(d).toLocal());
      } catch (e) {
        return d;
      }
    }
    if (d is DateTime) return DateFormat.yMd().add_jm().format(d.toLocal());
    return d;
  }
}
