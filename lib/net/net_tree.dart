import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/follow/follow_tree_node.dart';
import 'package:nerdster/nerdster_menu.dart';
import 'package:nerdster/net/net_bar.dart';
import 'package:nerdster/net/net_tile.dart';
import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/net/oneofus_tree_node.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

/// 2 structural views are supported: <oneofus> [NetTreeView].bOneofus or 'follow network'.
/// bOneofus: always uses a OneofusNetNode.
/// !bOneofus: use FollowNet or OneofusNet nodes depending on b([FollowNet].fcontext).
/// Total state is captured by:
/// - [FollowNet].fcontext
/// - [NetTreeView].bOneofus

class NetTreeView extends StatefulWidget {
  static ValueNotifier<String?> highlightToken = ValueNotifier<String?>(null);
  static ValueNotifier<bool> bOneofus = ValueNotifier<bool>(true);

  final NetTreeModel root;

  const NetTreeView(this.root, {super.key});

  static Future<void> show(context, {String? highlightToken}) async {
    await Comp.waitOnComps([followNet, keyLabels]);
    NetTreeView tree = NetTreeView(makeRoot());
    NetTreeView.highlightToken.value = highlightToken;
    // ignore: unawaited_futures
    Navigator.push(context, MaterialPageRoute(builder: (context) => tree));
    NetBar.bNetView.value = true;
  }

  static NetTreeModel makeRoot() {
    NetTreeModel root;
    if (bOneofus.value || followNet.fcontext == kOneofusContext) {
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

    Setting.get<bool>(SettingType.showKeys).addListener(listen);
    Setting.get<bool>(SettingType.showStatements).addListener(listen);

    NetTreeModel root = widget.root;
    treeController = TreeController<NetTreeModel>(
      roots: [root],
      childrenProvider: (NetTreeModel node) => node.children,
    );

    expandToHighlightToken();
  }

  void expandToHighlightToken() {
    treeController.expand(treeController.roots.first); // Expand a little by default.
    String? expandToToken = NetTreeView.highlightToken.value;
    if (b(expandToToken)) {
      // Tree structure could be Oneofus or Follow.
      // This doesn't work any longer as Follow tree view doesn't show delegate keys.
      // if (!Prefs.showEquivalentKeys.value) {
      //   expandToToken = followNet.delegate2oneofus[expandToToken];
      // }
      String expandToOneofusToken = followNet.delegate2oneofus[expandToToken] ?? expandToToken!;
      // Search BFS (first, shortest)
      NetTreeModel? netTreeModel = treeController.breadthFirstSearch(
          returnCondition: (x) => x.token == expandToOneofusToken);
      if (b(netTreeModel)) {
        NetTreeModel node = netTreeModel!;
        for (NetTreeModel x in node.path) {
          treeController.expand(x);
        }
        treeController.expand(node);
      }
    }
  }

  Future<void> listen() async {
    await Comp.waitOnComps([followNet, keyLabels]);
    // BUG: Witnessed in console:
    // A TreeController<NetTreeModel> was used after being disposed.
    // Once you have called dispose() on a TreeController<NetTreeModel>, it can no longer be used.
    treeController.roots = [NetTreeView.makeRoot()];
    treeController.rebuild();
    expandToHighlightToken();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    NetTreeView.bOneofus.removeListener(listen);
    followNet.removeListener(listen);
    keyLabels.removeListener(listen);

    Setting.get<bool>(SettingType.showKeys).removeListener(listen);
    Setting.get<bool>(SettingType.showStatements).removeListener(listen);

    treeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Expanded(child: NerdsterMenu()),
      ]),
      NetBar(),
      if (b(signInState.pov))
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
