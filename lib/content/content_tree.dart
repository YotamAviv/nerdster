import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_bar.dart';
import 'package:nerdster/content/content_tile.dart';
import 'package:nerdster/content/content_tree_node.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/nerdster_menu.dart';
import 'package:nerdster/net/net_bar.dart';
import 'package:nerdster/notifications_menu.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/qr_sign_in.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/verify.dart';

/// TODO: Migrate from flutter_fancy_tree_view 1.6.0 (discontinued replaced by two_dimensional_scrollables?
/// See: https://api.flutter.dev/flutter/widgets/TreeSliver-class.html
/// - I do use BFS or DFS search from flutter_fancy_tree_view to highlight nodes

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
class ContentTree extends StatefulWidget {
  static bool _firstTime = true;

  // So `message_handler` can obtain this widget's BuildContext
  static final GlobalKey<_ContentTreeState> contentKey = GlobalKey<_ContentTreeState>();
  static BuildContext? get rootContext => contentKey.currentContext;

  ContentTree({Key? key}) : super(key: key ?? contentKey);

  @override
  State<ContentTree> createState() => _ContentTreeState();
}

class _ContentTreeState extends State<ContentTree> {
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
    listen();
  }

  Future<void> listen() async {
    await Comp.waitOnComps([contentBase, keyLabels]);
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

  // CODE: This function might belong in main.dart or elsewhere.
  void kludgeDelayedInit(BuildContext context) {
    ContentTree._firstTime = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // KLUDGE: I haven't thought too much about the stored keys. This is for the web page to show the QR sign in.
      if (b(Uri.base.queryParameters['qrSignIn'])) {
        await qrSignIn(context);
      } else {
        await defaultSignIn(context);
      }

      // progress will call Navigator.pop(context) asynchronously, and so can't showTree first.
      await progress.make(() async {
        // A mess and maybe a BUG: I had a bug where fetching me (?oneofus=token) was broken, but I didn't see the notification.
        // I couldn't figure it out.
        // I added print statements and saw that I see
        //   oneofusNet-in, notifications cleared, corrupted, oneofusNet-out, and then a repeat but without the corruptiong.
        // I never figured it out, but commenting this line out seems to help ... ?
        // oneofusNet.listen();
        await Comp.waitOnComps([contentBase, keyLabels]);
      }, context);

      if (Setting.get(SettingType.netView).value) await NetBar.showTree(context);

      if (b(Uri.base.queryParameters['verify2'])) {
        final bool verifyImmediately = bs(Uri.base.queryParameters['verifyImmediately']);
        await showDialog(
            context: context,
            builder: (context) => Dialog(
                    // Doesn't work: shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
                    child: Navigator(onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                      builder: (_) => Verify(
                          input: Uri.base.queryParameters['verify2'],
                          verifyImmediately: verifyImmediately));
                })));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    NerdsterMenu nerdsterMenu = NerdsterMenu();
    NotificationsMenu();

    if (ContentTree._firstTime) kludgeDelayedInit(context);
    // I couldn't figure out to detect phone or big computer.
    bool newSmall = MediaQuery.of(context).size.width < 600;
    if (newSmall != isSmall.value) {
      // don't trigger a build during a build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        isSmall.value = newSmall;
      });
    }

    return Scaffold(
        body: SafeArea(
            child: Column(children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Expanded(child: nerdsterMenu),
        ],
      ),
      NetBar(),
      const ContentBar(),
      Expanded(
          child: SelectionArea(
              child: TreeView<ContentTreeNode>(
        treeController: treeController,
        nodeBuilder: (BuildContext context, TreeEntry<ContentTreeNode> entry) {
          return ContentTile(
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
