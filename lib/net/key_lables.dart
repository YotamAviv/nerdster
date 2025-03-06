import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';
import 'package:quiver/collection.dart';

const kMe = 'Me';

class KeyLabels with Comp, ChangeNotifier {
  static final KeyLabels _singleton = KeyLabels._internal();
  factory KeyLabels() => _singleton;
  KeyLabels._internal() {
    // supporters
    addSupporter(oneofusNet);
    oneofusNet.addListener(listen);
    addSupporter(followNet);
    followNet.addListener(listen);
  }

  // vars
  final BiMap<String, String> _token2name = BiMap<String, String>();

  // interface
  String? labelKey(String token) => _token2name[token];

  void listen() {
    setDirty();
    notifyListeners();
  }

  // Try to label (or strip):
  // - "gibberish" (crypto keys, tokens, ['signature', 'previous'] stripped)
  // - datetimes.,
  // - lists and maps of those above
  dynamic show(dynamic d) {
    if (d is Jsonish) {
      return show(d.json);
    } else if (d is Statement) {
      return show(d.json);
    } else if (d is Iterable) {
      return List.of(d.map(show)); // Json converter doesn't like Iterable, and so List.of
    } else if (d is Json && d['crv'] == 'Ed25519') {
      try {
        String token = getToken(d);
        if (labelKey(token) != null) {
          return labelKey(token);
        }
        // ignore: empty_catches
      } catch (e) {}
      return d;
    } else if (d is Map) {
      Map out = Map.of(d);
      out.remove('signature');
      out.remove('previous');
      return out.map((key, value) => MapEntry(show(key), show(value)));
    } else if (d is String) {
      String? keyLabel = labelKey(d);
      if (b(keyLabel)) {
        return keyLabel!;
      }
      try {
        return formatUiDatetime(parseIso(d));
        // ignore: empty_catches
      } catch (e) {}
      return d;
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

    _labelKeys();
    _labelDelegateKeys();

    assert(b(labelKey(signInState.center)));
  }

  void _labelKeys() {
    _labelMe();
    String meLabel = labelKey(signInState.center)!;
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

  void _labelDelegateKeys() {
    for (MapEntry<String, String> e in followNet.delegate2oneofus.entries) {
      _labelKey(e.key, '${labelKey(e.value)}-delegate');
    }
  }

  String _labelKey(String token, String name) {
    if (!_token2name.inverse.containsKey(name)) {
      _token2name[token] = name;
      return name;
    }
    for (int i = 0;; i++) {
      String altName = '$name ($i)';
      if (!_token2name.inverse.containsKey(altName)) {
        _token2name[token] = altName;
        return altName;
      }
    }
  }

  String _labelMe() {
    for (String t in oneofusNet.network.keys) {
      Fetcher f = Fetcher(t, kOneofusDomain);
      for (TrustStatement ts in distinct(f.statements)
          .cast<TrustStatement>()
          .where((s) => !NotificationsMenu.rejected.containsKey(s.token))) {
        if (ts.verb == TrustVerb.trust && ts.subjectToken == signInState.center) {
          String moniker = ts.moniker!;
          return _labelKey(signInState.center, moniker);
        }
      }
    }
    return _labelKey(signInState.center, kMe);
  }
}
