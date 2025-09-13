import 'package:collection/collection.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';

class FollowTreeNode extends NetTreeModel {
  Iterable<FollowTreeNode>? _children;
  final String? verbPastTense;

  static FollowTreeNode get root => FollowTreeNode([], token: signInState.pov);

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
  String get displayVerbPastTense => verbPastTense!;

  @override
  Iterable<NetTreeModel> get children {
    Comp.throwIfNotReady([followNet]);
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
    if (Setting.get<bool>(SettingType.showStatements).value) {
      for (Trust trust in followNode.cachedTrusts) {
        ContentStatement? followStatement = ContentStatement.find(trust.statementToken);
        if (followStatement == null) continue; // assume TrustStatement for default context.
        FollowTreeNode child =
            FollowTreeNode(nextPath, statement: followStatement, verbPastTense: 'followed');
        childStatements.add(child);
      }
      for (Block block in followNode.cachedBlocks) {
        ContentStatement? followStatement = ContentStatement.find(block.statementToken);
        if (followStatement == null) continue; // assume TrustStatement for default context.
        FollowTreeNode child =
            FollowTreeNode(nextPath, statement: followStatement, verbPastTense: 'blocked');
        childStatements.add(child);
      }
    }

    _children = [childNerds.values, childStatements].flattened;
    return _children!;
  }

  @override
  bool get canonical => true;
  @override
  String? get revokeAt => null;
  @override
  DateTime? get revokeAtTime => null;
}
