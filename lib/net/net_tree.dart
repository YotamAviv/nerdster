import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/follow/follow_tree_node.dart';
import 'package:nerdster/nerdster_menu.dart';
import 'package:nerdster/net/net_bar.dart';
import 'package:nerdster/net/net_tile.dart';
import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/net/oneofus_tree_node.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

/// 3 virtual screens or views (not full-on Flutter Routes):
/// - Content view
/// - Follow tree view
/// - Oneofus tree view
/// All 3 show the 'Follow' dropdown whichs shows and changes [FollowNet].fcontext
///
/// Follow tree view: uses a FollowNet node or a OneofusNetNode depending on [FollowNet].fcontext.
/// Oneofus tree view: always uses a OneofusNetNode.
///
/// Total state is captured by:
/// - [FollowNet].fcontext
/// - [NetTreeView].bOneofus

class NetTreeView extends StatefulWidget {
  static ValueNotifier<String?> highlightToken = ValueNotifier<String?>(null);
  static ValueNotifier<bool> bOneofus = ValueNotifier<bool>(false);

  final NetTreeModel root;

  const NetTreeView(this.root, {super.key});

  static Future<void> show(context, {String? highlightToken}) async {
    await Comp.waitOnComps([followNet, keyLabels]);
    NetTreeView tree = NetTreeView(makeRoot());
    NetTreeView.highlightToken.value = highlightToken;
    Navigator.push(context, MaterialPageRoute(builder: (context) => tree));
  }

  static makeRoot() {
    NetTreeModel root;
    if (bOneofus.value || !b(followNet.fcontext)) {
      root = OneofusTreeNode.root;
    } else {
      root = FollowTreeNode.root;
    }
    return root;
  }

  @override
  State<NetTreeView> createState() => _NetTreeViewState();
}

class _NetTreeViewState extends State<NetTreeView> {
  late final TreeController<NetTreeModel> treeController;

  @override
  void initState() {
    super.initState();
    NetTreeView.bOneofus.addListener(listen);
    followNet.addListener(listen);
    keyLabels.addListener(listen);

    NetTreeModel root = widget.root;
    treeController = TreeController<NetTreeModel>(
      roots: [root],
      childrenProvider: (NetTreeModel node) => node.children,
    );

    // Expand tree to highlightToken if applicable.
    String? expandToToken = NetTreeView.highlightToken.value;
    if (b(expandToToken)) {
      // This doesn't work any longer as Follow tree view doesn't show delegate keys.
      // if (!Prefs.showEquivalentKeys.value) {
      //   expandToToken = followNet.delegate2oneofus[expandToToken];
      // }
      TreeSearchResult result = treeController.search((node) => (node.token == expandToToken));
      Object? n = result.matches.keys.firstOrNull;
      if (b(n)) {
        NetTreeModel node = n as NetTreeModel;
        for (NetTreeModel x in node.path) {
          treeController.expand(x);
        }
        treeController.expand(node);
      }
    }
  }

  Future<void> listen() async {
    await Comp.waitOnComps([followNet, keyLabels]);
    treeController.roots = [NetTreeView.makeRoot()];
    treeController.rebuild();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    NetTreeView.bOneofus.removeListener(listen);
    followNet.removeListener(listen);
    keyLabels.removeListener(listen);

    treeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Column(children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Expanded(
            child: NerdsterMenu(),
          ),
        ],
      ),
      const NetBar(),
      Expanded(child: SelectionArea(child: NetTreeTree(treeController: treeController)))
    ])));
  }
}

class NetTreeTree extends StatelessWidget {
  const NetTreeTree({
    super.key,
    required this.treeController,
  });

  final TreeController<NetTreeModel> treeController;

  @override
  Widget build(BuildContext context) {
    if (!Comp.compsReady([followNet, keyLabels])) return const Text('loading..');
    return TreeView<NetTreeModel>(
      treeController: treeController,
      nodeBuilder: (BuildContext context, TreeEntry<NetTreeModel> entry) {
        return NetTile(
          key: UniqueKey(),
          entry: entry,
          onTap: () {
            treeController.toggleExpansion(entry.node);
          },
        );
      },
    );
  }
}
