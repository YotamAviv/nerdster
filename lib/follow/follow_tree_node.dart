import 'package:collection/collection.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';

class FollowTreeNode extends NetTreeModel {
  Iterable<FollowTreeNode>? _children;
  final String? verbPastTense;

  static FollowTreeNode get root => FollowTreeNode([], token: signInState.center);

  FollowTreeNode(super.path, {super.token, super.statement, this.verbPastTense}) {
    followNet.addListener(() {
      _children = null;
    });
  }

  @override
  String get moniker {
    if (b(statement)) {
      return keyLabels.labelKey(statement!.subjectToken)!;
    } else {
      return keyLabels.labelKey(token!)!;
    }
  }
  @override
  String get displayVerbPastTense {
    return verbPastTense!;
  }


  @override
  Iterable<NetTreeModel> get children {
    xssert(Comp.compsReady([followNet, oneofusEquiv, oneofusNet]));
    if (_children != null) return _children!;
    // Don't expand statements, !canoncial, or nodes already on path
    if (token == null || !canonical || path.map((n) => n.token).contains(token)) return [];

    final List<NetTreeModel> nextPath = List.of(path)..add(this);

    FollowNode followNode = FollowNode(token!);
    if (!followNode.processed) return [];

    final Map<String, FollowTreeNode> childNerds = <String, FollowTreeNode>{};
    for (Trust trust in followNode.cachedTrusts) {
      if (!followNet.oneofus2delegates.containsKey(trust.node.token)) continue;
      FollowTreeNode child = FollowTreeNode(nextPath, token: trust.node.token);
      childNerds[child.token!] = child;
    }

    List<FollowTreeNode> childStatements = <FollowTreeNode>[];
    if (Prefs.showStatements.value) {
      for (Trust trust in followNode.cachedTrusts) {
        FollowTreeNode child = FollowTreeNode(nextPath,
            statement: Statement.make(Jsonish.find(trust.statementToken)!), verbPastTense: 'followed');
        childStatements.add(child);
      }
      for (Block block in followNode.cachedBlocks) {
        FollowTreeNode child = FollowTreeNode(nextPath,
            statement: Statement.make(Jsonish.find(block.statementToken)!), verbPastTense: 'blocked');
        childStatements.add(child);
      }
    }

    _children = [childNerds.values, childStatements].flattened;
    return _children!;
  }
  
  @override
  bool get canonical => true;
  
  @override
  DateTime? get revokeAt => null;
}
