import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/follow/follow.dart';
import 'package:nerdster/js_widget.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/sign_in_menu.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

const (IconData, IconData) smileyIconPair =
    (Icons.sentiment_satisfied_outlined, Icons.sentiment_satisfied);
const (IconData, IconData) keyIconPair = (Icons.key_outlined, Icons.key);
const (IconData, IconData) revokedKeyIconPair = (Icons.key_off_outlined, Icons.key_off);
const (IconData, IconData) statementIconPair = (Icons.attachment_outlined, Icons.attachment);

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
  @override
  initState() {
    super.initState();
    Prefs.nice.addListener(listen);
    Prefs.showStatements.addListener(listen);
    Prefs.showJson.addListener(listen);
  }

  @override
  dispose() {
    Prefs.nice.removeListener(listen);
    Prefs.showStatements.removeListener(listen);
    Prefs.showJson.removeListener(listen);
    super.dispose();
  }

  Future<void> listen() async {
    await Comp.waitOnComps([oneofusEquiv, followNet]);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(Comp.compsReady([oneofusEquiv, followNet]));

    final NetTreeModel node = widget.entry.node;
    final bool isStatement = node.statement != null;

    String? text;
    if (isStatement) {
      text = '${node.displayStatementAtTime}: ${node.displayVerbPastTense} ';
    }

    String iconTooltip;
    Color iconColor = Colors.black;
    Color statementTextColor = Colors.black;
    (IconData, IconData) iconPair;

    if (!isStatement) {
      // WIP..
      // An EG is never replaced; only keys can be replaced
      //
      // A key is never followed, only EGs are followed

      iconTooltip = node.labelKeyPaths().join('\n');
      bool replaced = b(node.revokeAt);

      bool isFollowed = followNet.oneofus2delegates.containsKey(node.token);
      assert(!(!node.canonical && isFollowed));
      if (node.canonical) {
        // EG
        iconPair = smileyIconPair;

        if (isFollowed) iconColor = Colors.lightGreen;

        if (replaced) {
          // Can an EG (smiley) be revoked/replaced?
          // Bart trusts Milhouse trusts Sideshow replaces Bart before Bart's trust in Milhouse.
          // When center is Marge, Bart is decapitated, (a revoked EG with no valid replacement).
          iconColor = Colors.pink;
        }
      } else {
        // Key (delegate or equivalent)
        bool isDelegate = followNet.delegate2oneofus.containsKey(node.token);
        if (!replaced) {
          iconPair = keyIconPair;
        } else {
          iconPair = revokedKeyIconPair;
          iconTooltip = '$iconTooltip \nrevoked at: ${formatUiDatetime(node.revokeAt!)}';
        }
        if (isDelegate) {
          // From Oneofus KeyWidget: color = local ? Colors.blue.shade700 : Colors.blue.shade100;
          assert(b(widget.entry.node.token));
          iconColor = (widget.entry.node.token == signInState.signedInDelegate)
              ? Colors.blue.shade700
              : iconColor = Colors.blue.shade100;
        }
      }
    } else {
      // Statement
      iconTooltip = 'statement';
      iconPair = statementIconPair;
      if (node.rejected) {
        iconColor = Colors.red;
      }
      if (node.trustsNonCanonical) {
        iconColor = Colors.pink.shade100;
      }
      if (!node.isCanonicalStatement) {
        // statements by non-canonical keys in gray.
        statementTextColor = Colors.black38;
      }
    }

    List<Shadow>? shadows;
    if (b(NetTreeView.highlightToken.value)) {
      if (node.token == NetTreeView.highlightToken.value ||
          node.token == followNet.delegate2oneofus[NetTreeView.highlightToken.value]) {
        // iconColor = Colors.green.shade900;
        shadows = const <Shadow>[Shadow(color: Colors.pink, blurRadius: 5.0)];
      }
    }

    Icon openedIcon = Icon(
      iconPair.$1,
      color: iconColor,
      shadows: shadows,
    );
    Icon closedIcon = Icon(
      iconPair.$2,
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
            if (Prefs.showJson.value) JSWidget(json),
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
    // Don't allow following yourself.
    // Do allow following center in case I'm centered on someone else
    // All that said, we should survive statements that follow ourselves as that can happen with
    // claiming/clearing delegate statements, equivalence, etc...
    if (node.token == signInState.centerReset) {
      return;
    }
    String? value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy,
          details.globalPosition.dx, details.globalPosition.dy),
      items: [
        if (node.token != signInState.center)
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
    // No signing in as delegates
    bool clickable = b(node.token) && oneofusNet.network.containsKey(node.token);
    TextStyle? style = clickable ? linkStyle : null;
    return GestureDetector(
        onTapDown: (details) {
          if (clickable) {
            showPopUpMenuAtTap(context, details);
          }
        },
        child: Text(style: style, node.moniker));
  }
}
