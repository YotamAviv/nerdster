import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/follow/follow.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/js_widget.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/net/oneofus_equiv.dart';
import 'package:nerdster/net/oneofus_net.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/sign_in_menu.dart';
import 'package:nerdster/singletons.dart';

class NetTile extends StatefulWidget {
  const NetTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final TreeEntry<NetTreeModel> entry;
  final VoidCallback onTap;

  @override
  State<StatefulWidget> createState() {
    return _NetTileState();
  }
}

class _NetTileState extends State<NetTile> {
  _NetTileState() {
    Prefs.nice.addListener(listen);
    Prefs.showStatements.addListener(listen);
  }

  Future<void> listen() async {
    await Comp.waitOnComps([OneofusEquiv(), FollowNet()]);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    Prefs.nice.removeListener(listen);
    Prefs.showStatements.removeListener(listen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(Comp.compsReady([OneofusEquiv(), FollowNet()]));

    final NetTreeModel node = widget.entry.node;
    final bool isStatement = node.statement != null;

    String? text;
    if (isStatement) {
      text = '${node.displayStatementAtTime}: ${node.displayVerbPastTense} ';
    }

    String iconTooltip = '';
    Color? iconColor = Colors.black;
    List<IconData> iconDatas;
    Color? statementTextColor = Colors.black;

    if (!isStatement) {
      // Nerd
      if (node.canonical) {
        iconDatas = tileType2icon['nerd']!;
      } else {
        // delegate key, replaced key
        iconDatas = tileType2icon['key']!;
      }

      iconTooltip = node.labelKeyPaths().join('\n');
      if (node.revokeAt != null) {
        iconColor = Colors.pink.shade100;
        iconTooltip = '$iconTooltip \nreplaced at: ${formatUiDatetime(node.revokeAt!)}';
      } else {
        // Newish, not sure...
        if (widget.entry.node.canonical &&
            followNet.oneofus2delegates.containsKey(widget.entry.node.token)) {
          iconColor = Colors.lightGreen;
        }
      }
    } else {
      // Statement
      if (node.rejected) {
        print(OneofusNet().rejected);
        iconColor = Colors.red;
      }
      if (node.trustsNonCanonical) {
        iconColor = Colors.pink.shade100;
      }
      iconDatas = tileType2icon[kOneofusType]!;
      if (!node.isCanonicalStatement) {
        // statements by non-canonical keys in gray.
        statementTextColor = Colors.black38;
      }
    }

    List<Shadow>? shadows;
    if (b(NetTreeView.highlightToken.value)) {
      if (node.token == NetTreeView.highlightToken.value ||
          node.token == FollowNet().delegate2oneofus[NetTreeView.highlightToken.value]) {
        // iconColor = Colors.green.shade900;
        shadows = const <Shadow>[Shadow(color: Colors.pink, blurRadius: 5.0)];
      }
    }

    Icon openedIcon = Icon(
      iconDatas[0],
      color: iconColor,
      shadows: shadows,
    );
    Icon closedIcon = Icon(
      iconDatas[1],
      color: iconColor,
      shadows: shadows,
    );

    Json json = isStatement ? node.statement!.json : (Jsonish.find(node.token!))!.json;

    return TreeIndentation(
        entry: widget.entry,
        guide: const IndentGuide.connectingLines(indent: 48),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Tooltip(
              message: iconTooltip,
              child: FolderButton(
                  icon: closedIcon,
                  openedIcon: openedIcon,
                  closedIcon: closedIcon,
                  isOpen: widget.entry.hasChildren ? widget.entry.isExpanded : null,
                  onPressed: widget.entry.hasChildren ? widget.onTap : null),
            ),
            if (Prefs.showStatements.value) JSWidget(json),
            if (b(text))
              Text(
                text!,
                style: TextStyle(color: statementTextColor),
              ),
            _MonikerWidget(node),
          ])
        ]));
  }
}

// CONSIDER: more tooltips with paths.
class _MonikerWidget extends StatelessWidget {
  final NetTreeModel node;

  const _MonikerWidget(this.node);

  Future<void> showPopUpMenuAtTap(BuildContext context, TapDownDetails details) async {
    if (node.token == signInState.center) return;
    String? value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy,
          details.globalPosition.dx, details.globalPosition.dy),
      items: [
        const PopupMenuItem<String>(value: 'recenter', child: Text('recenter')),
        const PopupMenuItem<String>(value: 'follow...', child: Text('follow...')),
      ],
      elevation: 8.0,
    );
    if (value == 'recenter') {
      await recenter(node.token!, context);
    } else if (value == 'follow...') {
      await follow(node.token!, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTapDown: (details) {
          // No signing in as delegates
          if (b(node.token) && OneofusNet().network.containsKey(node.token)) {
            showPopUpMenuAtTap(context, details);
          }
        },
        child: Text(node.moniker));
  }
}
