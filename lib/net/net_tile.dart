import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/follow/follow.dart';
import 'package:nerdster/js_widget.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
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
    Prefs.showStatements.addListener(listen);
    Prefs.showJson.addListener(listen);
  }

  @override
  dispose() {
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
      text = '${node.displayStatementAtTime}: ${node.displayVerbPastTense} ${node.moniker}';
    }

    String iconTooltip;
    Color iconColor = Colors.black;
    Color statementTextColor = Colors.black;
    (IconData, IconData) iconPair;

    if (!isStatement) {
      iconTooltip = node.labelKeyPaths().join('\n');
      bool revoked = b(node.revokeAt);
      bool isFollowed = followNet.oneofus2delegates.containsKey(node.token);
      assert(!(!node.canonical && isFollowed));
      if (node.canonical) {
        // EG
        iconPair = smileyIconPair;
        if (isFollowed) iconColor = Colors.lightGreen;
        if (revoked) {
          // Can an EG (smiley) be revoked/replaced?
          // Bart trusts Milhouse trusts Sideshow replaces Bart before Bart's trust in Milhouse.
          // When center is Marge, Bart is decapitated, (a revoked EG with no valid replacement).
          iconColor = Colors.pink;
        }
      } else {
        // Key (delegate or equivalent)
        iconColor = Colors.black54;
        bool isDelegate = followNet.delegate2oneofus.containsKey(node.token);
        if (!revoked) {
          iconPair = keyIconPair;
        } else {
          iconPair = revokedKeyIconPair;
          String replacedOrRevoked = isDelegate ? 'revoked' : 'replaced';
          iconTooltip = '$iconTooltip \n$replacedOrRevoked at: ${formatUiDatetime(node.revokeAt!)}';
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
      iconColor = Colors.black;
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
        statementTextColor = Colors.black54;
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

    Jsonish jsonish = isStatement ? node.statement!.jsonish : (Jsonish.find(node.token!))!;

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
                  onPressed: widget.onTap),
            ),
            if (Prefs.showJson.value) JSWidget(jsonish),
            if (isStatement)
              Text(
                text!,
                style: TextStyle(color: statementTextColor),
              ),
            if (!isStatement) _MonikerWidget(node)
          ])
        ]));
  }
}

// CONSIDER: more tooltips with paths.
class _MonikerWidget extends StatelessWidget {
  final NetTreeModel node;
  late final List<PopupMenuEntry<String>> items;
  late final bool bOneofus;

  _MonikerWidget(this.node) {
    bOneofus = oneofusNet.network.containsKey(node.token);
    items = [
      if (bOneofus && node.token != signInState.center)
        const PopupMenuItem<String>(value: 'recenter', child: Text('recenter')),
      // Don't encourage following yourself.
      if (bOneofus && node.token != signInState.centerReset)
        const PopupMenuItem<String>(value: 'follow...', child: Text('follow...')),
      if (Prefs.showStatements.value)
        const PopupMenuItem<String>(value: 'statements', child: Text('statements...'))
    ];
  }

  Future<void> showPopUpMenuAtTap(BuildContext context, TapDownDetails details) async {
    if (items.isEmpty) return;
    String? value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy,
          details.globalPosition.dx, details.globalPosition.dy),
      items: items,
      elevation: 8.0,
    );
    if (value == 'recenter') {
      await progress.make(() {
        signInState.center = node.token!;
      }, context);
    } else if (value == 'follow') {
      await follow(node.token!, context);
    } else if (value == 'statements') {
      String link;
      // DEFER: ?revokedAt=...
      String domain = bOneofus ? kOneofusDomain : kNerdsterDomain;
      link = '${exportUrl[fireChoice]![domain]}?token=${node.token!}';
      // DEFER: copy floater, (maybe unite with Nerdster link dialog)
      await alert(
          'Published statements',
          '''Signed and published by this key:
$link''',
          ['Okay'],
          context);
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(b(node.token));
    bool clickable = items.isNotEmpty;
    TextStyle? style = clickable ? linkStyle : null;
    return GestureDetector(
        onTapDown: (details) {
          if (clickable) showPopUpMenuAtTap(context, details);
        },
        child: Text(style: style, node.moniker));
  }
}
