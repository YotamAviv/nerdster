import 'package:collection/collection.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/follow/follow_tree_node.dart';
import 'package:nerdster/net/net_node.dart';
import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';

/// Plan for NetBar on every route
/// Content:
/// - context, includes <one-of-us>
/// - follow degrees, N/A when <one-of-us>
/// FollowNet:
/// - context, includes <one-of-us>
/// - follow degrees, N/A when <one-of-us>
/// - expanding works
/// - maybe no => to next route
/// Oneofus:
/// - context, includes <one-of-us>
/// - follow degrees, N/A when <one-of-us>
/// - show colors for followed
///
/// Any one-of-us options / tweeks / settings?
/// - degrees?
/// - max?
/// - paths? (unlikely (ever))
/// One of degrees or max is necessary, but I don't necessarily need to show it; it could end up
/// in the Pref (or even Dev) menu.
///

/// [FollowTreeNode] is currently a subclass of this, but it'd be cleaner to
/// - an abstract base class TreeNode and
/// - 2 subclasses: {OneofusTreeNode, FollowTreeNode}
///
/// This tries to be the model behind the NetTreeView view. CONSIDER: Rename NetTreeModel
/// Sometimes this is a nerd (either canonical EG or equivalent key);
/// sometimes it's a statement about a nerd.
class OneofusTreeNode extends NetTreeModel {
  // Node
  @override
  final bool canonical;
  @override
  final DateTime? revokeAt;
  Iterable<OneofusTreeNode>? _children;

  static OneofusTreeNode get root =>
      OneofusTreeNode([], token: signInState.center, canonical: true);

  OneofusTreeNode(super.path,
      {super.token, super.statement, this.canonical = false, this.revokeAt}) {
    oneofusEquiv.addListener(() {
      _children = null;
    });
  }

  /// Prune the cyclic graph into a bounded tree:
  /// - Don't show children that are already on the path.
  @override
  Iterable<OneofusTreeNode> get children {
    assert(Comp.compsReady([followNet, oneofusEquiv, oneofusNet]));
    if (_children != null) return _children!;
    // Don't expand statements, !canoncial, or nodes already on path
    if (token == null || !canonical || path.map((n) => n.token).contains(token)) return [];

    final List<NetTreeModel> nextPath = List.of(path)..add(this);

    final Map<String, OneofusTreeNode> childNerds = <String, OneofusTreeNode>{};
    NetNode netNode = NetNode(token);
    for (NetNode childNetNode in netNode.children) {
      Fetcher fetcher = Fetcher(childNetNode.token, kOneofusDomain);
      assert(fetcher.isCached);
      OneofusTreeNode child = OneofusTreeNode(nextPath,
          token: childNetNode.token, canonical: true, revokeAt: fetcher.revokeAtTime);
      childNerds[childNetNode.token] = child;
    }

    // TODO: Test: dump NerdTree in !minimalist mode. Capture these:
    // - isCanonical (shown as face) / isDelegate (shown as key)
    // - revokeAt time (replaced) (shown in pink) / blocked (shown in red)

    // non-canonical children - delegates or replaced keys in the NerdTree.
    final Map<String, OneofusTreeNode> childKeys = <String, OneofusTreeNode>{};
    if (Prefs.showEquivalentKeys.value && canonical) {
      for (String equiv in oneofusEquiv.getEquivalents(token).whereNot((s) => s == token)) {
        Node fetcherNode = oneofusNet.network[equiv]!;
        OneofusTreeNode child = OneofusTreeNode(nextPath,
            token: equiv, canonical: false, revokeAt: fetcherNode.revokeAtTime);
        childKeys[equiv] = child;
      }
      if (b(followNet.oneofus2delegates[token])) {
        for (String delegate in followNet.oneofus2delegates[token]!) {
          OneofusTreeNode child = OneofusTreeNode(nextPath,
              token: delegate,
              canonical: false,
              revokeAt: followNet.delegate2fetcher[delegate]!.revokeAtTime);
          childKeys[delegate] = child;
        }
      }
    }

    List<OneofusTreeNode> childStatements = <OneofusTreeNode>[];
    if (Prefs.showTrustStatements.value) {
      // show trust statements made by this key
      for (TrustStatement statement
          in distinct(Fetcher(token!, kOneofusDomain).statements).cast<TrustStatement>()) {
        childStatements.add(OneofusTreeNode(path, statement: statement));
      }
      // (Same: childStatements.addAll(Fetcher(token!, kOneofusDomain).statements.cast().map((s) => NetTreeNode(path, statement: s)));)
      if (canonical) {
        // show trust statements from equivalent keys as well if I'm canonical.
        // TODO: Add a test where equivlent key statements matter. Homer has those, but they're not dumped.
        for (String equiv
            in oneofusEquiv.getEquivalents(token!).whereNot((equiv) => equiv == token)) {
          for (TrustStatement statement
              in distinct(Fetcher(equiv, kOneofusDomain).statements).cast()) {
            childStatements.add(OneofusTreeNode(path, statement: statement));
          }
        }
      }
    }

    _children = [childNerds.values, childKeys.values, childStatements].flattened;
    return _children!;
  }
}
