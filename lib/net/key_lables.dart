import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/measure.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';
import 'package:quiver/collection.dart';

const kMe = 'Me';
const kUnknown = '<unknown>';

/// CODE: Code duplication from a quick separation of KeyLables to KeyLables and OneofusLables just now.
/// The reason was so that FollowNet (which assigns delegates) can report progress with Oneofus lables.
/// It looks like that's limited to just _labelKey(..).
///
/// TODO: When making FollowNet depend on OneofusLabels, I was surprised to find that KeyLabels
/// didn't depend on OneofusEquiv. I wonder if doing so would make the code simpler (or correct).
class OneofusLabels with Comp, ChangeNotifier {
  static final OneofusLabels _singleton = OneofusLabels._internal();
  factory OneofusLabels() => _singleton;
  OneofusLabels._internal() {
    // supporters
    addSupporter(oneofusNet);
    oneofusNet.addListener(listen);
  }

  // vars
  final BiMap<String, String> _token2name = BiMap<String, String>();

  // interface
  String? labelKey(String token) => _token2name[token];

  void listen() {
    setDirty();
    notifyListeners();
  }

  @override
  Future<void> process() async {
    throwIfSupportersNotReady();
    _token2name.clear();
    if (!b(signInState.center)) return;

    _labelKeys();

    assert(b(labelKey(signInState.center!)));
    // There was a bug in JsonDisplay in CredentialsWidget where as we're loading, we don't label
    // our own key correctly.
    // That's when I noticed that we don't notify upon becoming ready.
    // That's been fixed a different way waitUntilReady..
    // CONSIDER: notifyListeners();
  }

  void _labelKeys() {
    _labelMe();
    String meLabel = labelKey(signInState.center!)!;
    for (MapEntry<String, Node> e in oneofusNet.network.entries.skip(1)) {
      String token = e.key;
      Path path = e.value.paths.first;
      // We walk the path because some of the edges are 'replace' which don't have a moniker.
      for (Trust edge in path.reversed) {
        String statementToken = edge.statementToken;
        TrustStatement statement = TrustStatement.find(statementToken)!;
        if (statement.verb == TrustVerb.replace && statement.iToken == signInState.center) {
          _labelKey(token, meLabel);
          break;
        }
        if (statement.verb == TrustVerb.trust) {
          _labelKey(token, statement.moniker!);
          break;
        }
      }
      assert(_token2name.containsKey(token), token);
    }
  }

  String _labelKey(String token, String name) {
    if (!_token2name.inverse.containsKey(name)) {
      _token2name[token] = name;
      return name;
    }
    for (int i = 2;; i++) {
      String altName = '$name ($i)';
      if (!_token2name.inverse.containsKey(altName)) {
        _token2name[token] = altName;
        return altName;
      }
    }
  }

  String _labelMe() {
    for (String t in oneofusNet.network.keys) {
      TrustStatement? ts = Fetcher(t, kOneofusDomain)
          .statements
          .cast<TrustStatement>()
          .firstWhereOrNull((ts) =>
              !notifications.rejected.containsKey(ts.token) &&
              ts.verb == TrustVerb.trust &&
              ts.subjectToken == signInState.center);
      if (b(ts)) return _labelKey(signInState.center!, ts!.moniker!);
    }
    return _labelKey(signInState.center!, kMe);
  }
}

class KeyLabels with Comp, ChangeNotifier implements Interpreter {
  static final KeyLabels _singleton = KeyLabels._internal();
  factory KeyLabels() => _singleton;
  KeyLabels._internal() {
    // supporters
    addSupporter(oneofusLabels);
    oneofusLabels.addListener(listen);
    addSupporter(followNet);
    followNet.addListener(listen);
  }

  // vars
  final BiMap<String, String> _token2name = BiMap<String, String>();

  // interface
  String? labelKey(String token) => _token2name[token] ?? oneofusLabels.labelKey(token);

  void listen() {
    setDirty();
    notifyListeners();
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
        return b(labelKey(token)) ? labelKey(token) : kUnknown;
      } catch (e) {
        return d;
      }
    } else if (d is Map) {
      Map out = Map.of(d);
      out.remove('signature');
      out.remove('previous');
      return out.map((key, value) => MapEntry(interpret(key), interpret(value)));
    } else if (d is String) {
      String? keyLabel = labelKey(d);
      if (b(keyLabel)) return keyLabel!;
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

  @override
  Future<void> process() async {
    throwIfSupportersNotReady();
    _token2name.clear();
    _labelDelegateKeys();
  }

  void _labelDelegateKeys() {
    for (MapEntry<String, String> e in followNet.delegate2oneofus.entries) {
      _labelKey(e.key, '${labelKey(e.value)}@nerdster.org');
    }
  }

  String _labelKey(String token, String name) {
    if (!_token2name.inverse.containsKey(name)) {
      _token2name[token] = name;
      return name;
    }
    for (int i = 2;; i++) {
      String altName = '$name ($i)';
      if (!_token2name.inverse.containsKey(altName)) {
        _token2name[token] = altName;
        return altName;
      }
    }
  }

  @override
  Measure get measure => Measure('labels');
}
