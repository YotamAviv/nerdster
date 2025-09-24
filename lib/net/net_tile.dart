import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/follow/follow.dart';
import 'package:nerdster/js_widget.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/json_display.dart';
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
    Setting.get<bool>(SettingType.showCrypto).addListener(listen);
  }

  @override
  dispose() {
    Setting.get<bool>(SettingType.showCrypto).removeListener(listen);
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
        assert(!revoked); // An EG (smiley) cannot be revoked
      } else {
        // Key (delegate or equivalent)
        iconColor = Colors.black54;
        bool isDelegate = followNet.delegate2oneofus.containsKey(node.token);
        if (!revoked) {
          iconPair = keyIconPair;
        } else {
          iconPair = revokedKeyIconPair;
          String replacedOrRevoked = isDelegate ? 'revoked' : 'replaced';
          String revokeAtTime =
              node.revokeAtTime == date0 ? '<since always>' : formatUiDatetime(node.revokeAtTime!);
          iconTooltip = '$iconTooltip \n$replacedOrRevoked at: $revokeAtTime';
        }
        if (isDelegate) {
          // From Oneofus KeyWidget: color = local ? Colors.blue.shade700 : Colors.blue.shade100;
          assert(b(widget.entry.node.token));
          iconColor = (widget.entry.node.token == signInState.delegate)
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
    final String? highlightToken = NetTreeView.highlightToken.value;
    if (b(NetTreeView.highlightToken.value)) {
      assert(!oneofusNet.network.containsKey(highlightToken!),
          'expecting delegate token, but subject to future changes..');
      if (followNet.delegate2oneofus.containsKey(highlightToken)) {
        if (node.token == highlightToken ||
            node.token == followNet.delegate2oneofus[highlightToken]) {
          shadows = const <Shadow>[Shadow(color: Colors.orange, blurRadius: 5.0)];
        }
      }
    }

    final Icon openedIcon = Icon(iconPair.$1, color: iconColor, shadows: shadows);
    final Icon closedIcon = Icon(iconPair.$2, color: iconColor, shadows: shadows);
    final Jsonish jsonish = isStatement ? node.statement!.jsonish : (Jsonish.find(node.token!))!;

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
            if (Setting.get<bool>(SettingType.showCrypto).value) JSWidget(jsonish),
            if (isStatement) Text(text!, style: TextStyle(color: statementTextColor)),
            if (!isStatement) _MonikerWidget(node)
          ])
        ]));
  }
}

const kRecenter = "PoV";
const kFollow = "Follow...";
const kStatements = "Statements...";

// CONSIDER: more tooltips with paths.
class _MonikerWidget extends StatelessWidget {
  final NetTreeModel node;
  late final List<PopupMenuEntry<String>> items;
  late final bool bOneofus;

  _MonikerWidget(this.node) {
    bOneofus = oneofusNet.network.containsKey(node.token);
    String moniker = keyLabels.interpret(node.token).toString().trim();
    items = [
      if (bOneofus && node.token != signInState.pov)
        PopupMenuItem<String>(value: kRecenter, child: Text("Use $moniker's Point of View")),
      // Don't encourage following yourself.
      if (bOneofus && node.token != signInState.identity)
        PopupMenuItem<String>(value: kFollow, child: Text("View/change how I follow $moniker...")),
      if (Setting.get<bool>(SettingType.showCrypto).value)
        PopupMenuItem<String>(value: kStatements, child: Text("$moniker's published statements..."))
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
    if (value == kRecenter) {
      await progress.make(() async {
        signInState.pov = node.token!;
        await Comp.waitOnComps([keyLabels, contentBase]);
      }, context);
    } else if (value == kFollow) {
      await follow(node.token!, context);
    } else if (value == kStatements) {
      String token = node.token!;
      String domain = bOneofus ? kOneofusDomain : kNerdsterDomain;
      if (fireChoice != FireChoice.fake) {
        var spec = !b(node.revokeAt) ? token : jsonEncode({token: node.revokeAt});
        Uri uri = Fetcher.makeSimpleUri(domain, spec);
        String moniker = keyLabels.interpret(node.token).toString();
        await alert("$moniker's signed, published statements", uri.toString(), ['Okay'], context);
      } else {
        Iterable statements = Fetcher(token, domain).statements;
        List<Json> jsons = List.from(statements.map((s) => s.json));
        Json j = {token: jsons};
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
                title: Text('Signed by this key'),
                content: JsonDisplay(j),
                actions: [
                  TextButton(child: Text('Okay'), onPressed: () => Navigator.of(context).pop())
                ]);
          },
        );
      }
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
