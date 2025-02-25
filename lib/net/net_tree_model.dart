import 'dart:collection';

import 'package:nerdster/comp.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';

abstract class NetTreeModel {
  /// Note that ValidNode contains all paths, but those are web-of-trust keys.
  final List<NetTreeModel> path;
  // Node
  final String? token;
   // Statement (not a TrustStatement because this class is a parent of [FollowTreeNode])
  final Statement? statement;

  NetTreeModel(this.path, {this.token, this.statement});

  List<String> labelKeyPaths() {
    xssert(b(token));
    String rootLabel = keyLabels.labelKey(signInState.center)!;
    // Special case for me. no paths.
    if (token == signInState.center) return [rootLabel];

    // DEFER: We don't show much for delegate keys.
    if (followNet.delegate2oneofus.containsKey(token)) return ['delegate key'];

    List<String> labeledKeyPaths = <String>[];
    for (List<LabeledEdge> labeledKeyPath in labelPathsX(token!)) {
      String labeledPath = labeledKeyPath.map((e) => e.edgeLabel).join('->');
      labeledKeyPaths.add('$rootLabel->$labeledPath');
    }
    return labeledKeyPaths;
  }

  String labelPath() => path.map((node) => node.moniker).join("->");

  String get moniker {
    if (b(statement)) {
      // DEFER: Is '<!trusted>' good enough?
      // Yes, if someone is blocked, then they're not trusted, not in the network.
      // But it would be nice to know who it is; if there are are others paths of trust to
      // them, then we attempt to name them.
      return keyLabels.labelKey((statement as TrustStatement).subjectToken) ?? '<!trusted>';
    } else {
      return keyLabels.labelKey(token!)!;
    }
  }
  bool get canonical;
  DateTime? get revokeAt;
  String get displayStatementAtTime => '@${formatUiDatetime(statement!.time)}';
  String get displayVerbPastTense {
    return (statement as TrustStatement).verb.pastTense;
  }
  bool get rejected => oneofusNet.rejected.containsKey(statement!.token);
  bool get trustsNonCanonical => oneofusEquiv.trustNonCanonical.containsKey(statement!.token);
  bool get isCanonicalStatement =>
      oneofusEquiv.getCanonical(statement!.iToken) == statement!.iToken;

  // For use in dump for testing. TEST: include statements in testing.
  @override
  String toString() {
    List<String> items = <String>[];
    if (token != null) {
      items.add('N');
      items.add('${keyLabels.show(token)}-$canonical');
      if (b(revokeAt)) {
        // Timezone test issue: I think that I now use local time at both ends (state 
        // and dump in local time).
        items.add(formatUiDatetime(revokeAt!));
      }
      items.add(labelPath());
    } else {
      items.add('S');
      items.add(statement!.token);
      items.add(displayStatementAtTime);
      items.add(displayVerbPastTense);
      items.add(moniker);
      if (rejected) {
        items.add(' rejected');
      }
      if (trustsNonCanonical) {
        items.add(' trustsNonCanonical');
      }
      if (trustsNonCanonical) {
        items.add(' nonCanonicalKey');
      }
    }
    return items.join(':');
  }

  /// CODE: ... I can probably take a lot of this out.
  /// Formerly also for dumping and tests
  String hashString() {
    List<String> items = <String>[];
    if (token != null) {
      items.add('N');
      items.add('${keyLabels.show(token)}-$canonical');
      if (b(revokeAt)) {
        items.add(formatIso(revokeAt!));
      }
      items.add(labelPath());
    } else {
      items.add('S');
      items.add(statement!.token);
    }
    return items.join(':');
  }

  // Hack'ish and dangerous, possibly wrong and buggy: I want the tree to remain expanded as it is
  // even as we switch from OneofusTreeNodes to FollowTreeNodes, and so even though
  // FollowTreeNode != NetTreeNode, I do.
  // (These are not factory singleton'ish like other nodes, and so that might help.)
  @override
  bool operator ==(other) {
    return other is NetTreeModel && other.token == token;
  }

  @override
  int get hashCode => hashString().hashCode;

  /// Prune the cyclic graph into a bounded tree:
  /// - Don't show children that are already on the path.
  Iterable<NetTreeModel> get children;

  Future<Json> dump() async {
    await Comp.waitOnComps([oneofusEquiv, followNet]);
    LinkedHashMap<String, dynamic> map = LinkedHashMap<String, dynamic>();
    map[toString()] = _dumpChildren();
    return map;
  }

  dynamic _dumpChildren() {
    LinkedHashMap<dynamic, dynamic> map = LinkedHashMap<dynamic, dynamic>();
    for (NetTreeModel child in children) {
      map[child.toString()] = child._dumpChildren();
    }
    return map;
  }
}

/// The Nerdster or Oneofus don't know who you are. Your trusted associates trust you and label
/// your moniker when doing so.
/// This applies to all trusts, and so a given trust from say 'bart' to 'homer' with moniker 'dad'
/// could be viewed differently form different perspectives. From Maggies's for example it might
/// be from 'brother' to 'popsicle', who knows..
/// The code here captures that for us, but even though the UI currently doesn't use much of it.
class LabeledEdge {
  final String keyLabel;
  final String edgeLabel;

  LabeledEdge(this.keyLabel, this.edgeLabel);

  Json toJson() => {keyLabel: edgeLabel};
  // The Map used above is just a pair, not a really a map. Below is a natual alternative but requires more text.
  // Json toJson() => {'key': keyLabel, 'edge': edgeLabel};
}

LabeledEdge labelTrust(Trust trust) {
  String trustMoniker = TrustStatement.find(trust.statementToken)!.moniker!;
  String keyLabel = keyLabels.labelKey(trust.node.token)!;
  return LabeledEdge(trustMoniker, keyLabel);
}

List<LabeledEdge> labelPathX(Path path) {
  List<LabeledEdge> out = <LabeledEdge>[];
  for (Trust trust in path.sublist(1)) {
    TrustStatement statement = TrustStatement.find(trust.statementToken)!;
    String moniker;
    if (statement.verb == TrustVerb.trust) {
      moniker = statement.moniker!;
    } else {
      xssert(statement.verb == TrustVerb.replace);
      moniker = '(replaced)';
    }
    LabeledEdge labeledEdge = LabeledEdge(keyLabels.labelKey(trust.node.token)!, moniker);
    out.add(labeledEdge);
  }
  return out;
}

List<List<LabeledEdge>> labelPathsX(String token) {
  List<List<LabeledEdge>> out = <List<LabeledEdge>>[];
  for (Path path in oneofusNet.network[token]!.paths) {
    out.add(labelPathX(path));
  }
  return out;
}
