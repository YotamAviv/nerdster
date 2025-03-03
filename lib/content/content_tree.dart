import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_bar.dart';
import 'package:nerdster/content/content_tile.dart';
import 'package:nerdster/content/content_tree_node.dart';
import 'package:nerdster/nerdster_menu.dart';
import 'package:nerdster/net/net_bar.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

/// StatefulWidget stuff...
/// OouTop / SubjectNode / (future PersonNode) is our model (state) that needs to be listened to by the state of our tree widget.
///
/// I expect changes when
/// - I use the app to rate/comment
///   One [StatementNode] should be added somewhere (or in multiple places (related..)).
///   One or more (related and other reasons) [ContentTreeNode]s should change
/// - I relate/equate
///   One [StatementNode] should be added somewhere (or in multiple places (related..)).
///   Several [ContentTreeNode]s may change both values and children ([StatementNode]s)
/// - I change the network spec, a key is revoked, refresh, etc...
///   Everything might change.
///   That said, quite a bit might stay the same.
/// - I re-sort ([ContentTreeNode]s were sorted by avg(rating). Or I rated and clicked sort again.
///   Only order in the top level tree should change.
///
/// Regardless of learning and experimenting, there's practicing and percieved progress, and so I'll
///
/// DEFER: UI: Try 3 dots on right side:
///   https://api.flutter.dev/flutter/material/MenuAnchor-class.html
class ContentTreeView extends StatefulWidget {
  static bool _firstTime = true;

  const ContentTreeView({super.key});

  @override
  State<ContentTreeView> createState() => _ContentTreeViewState();
}

class _ContentTreeViewState extends State<ContentTreeView> {
  late final TreeController<ContentTreeNode> treeController;

  @override
  void initState() {
    super.initState();
    treeController = TreeController<ContentTreeNode>(
      roots: contentBase.roots,
      childrenProvider: (ContentTreeNode node) => node.getChildren(),
    );

    contentBase.addListener(listen);
    keyLabels.addListener(listen);

    // Check start with network view
    // I don't like how I've done this.
    // - content shows up briefly before disappearing
    // - params are dealt with both here and in NetBar
    Map<String, String> params = Uri.base.queryParameters;
    if (bs(params['netView'])) {
      NetBar.showTree(context);
    }

    listen();
  }

  Future<void> listen() async {
    await Comp.waitOnComps([followNet, contentBase, keyLabels]);
    treeController.roots = contentBase.roots;
    treeController.rebuild();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    contentBase.removeListener(listen);
    keyLabels.removeListener(listen);
    treeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ContentTreeView._firstTime) {
      // ignore: unawaited_futures
      ContentTreeView._firstTime = false;
      BarRefresh.refresh(context);
    }

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
      NetBar(),
      const ContentBar(),
      Expanded(
          child: SelectionArea(
              child: TreeView<ContentTreeNode>(
        treeController: treeController,
        nodeBuilder: (BuildContext context, TreeEntry<ContentTreeNode> entry) {
          return SubjectTile(
            key: UniqueKey(),
            entry: entry,
            onTap: () {
              treeController.toggleExpansion(entry.node);
            },
          );
        },
      )))
    ])));
  }
}
