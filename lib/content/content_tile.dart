import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/content/content_base.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/content_tree_node.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/content/props.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/js_widget.dart';
import 'package:nerdster/net/key_lables.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/util_ui.dart';

class SubjectTile extends StatefulWidget {
  const SubjectTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final TreeEntry<ContentTreeNode> entry;
  final VoidCallback onTap;

  @override
  State<StatefulWidget> createState() {
    return _SubjectState();
  }
}

class _SubjectState extends State<SubjectTile> {
  Icon relateIcon = const Icon(Icons.balance);

  _SubjectState() {
    Prefs.nice.addListener(listener);
    Prefs.showStatements.addListener(listener);
  }

  listener() async {
    await ContentBase().waitUntilReady();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(ContentBase().ready);

    final ContentTreeNode subjectNode = widget.entry.node;

    final bool isStatement = subjectNode.subject.json.containsKey('statement');
    ContentStatement? statement;
    final String tileType;
    if (isStatement) {
      tileType = subjectNode.subject.json['statement'];
      statement = ContentStatement(subjectNode.subject);
    } else {
      tileType = subjectNode.subject.json['contentType'];
    }

    String? subjectTooltip;
    Color? iconColor;
    if (subjectNode.equivalent) {
      iconColor = Colors.pink;
      subjectTooltip = 'equivalent of parent';
    } else if (subjectNode.related) {
      iconColor = Colors.lightBlue;
      subjectTooltip = 'related to parent';
    }

    List<IconData> iconDatas = tileType2icon[tileType]!;
    Icon openedIcon = Icon(iconDatas[0], color: iconColor);
    Icon closedIcon = Icon(iconDatas[1], color: iconColor);
    if (iconColor != null) {
      openedIcon = Icon(iconDatas[0], color: iconColor);
      closedIcon = Icon(iconDatas[1], color: iconColor);
    } else {
      openedIcon = Icon(iconDatas[0]);
      closedIcon = Icon(iconDatas[1]);
    }

    Widget? commentWidget;
    if (b(statement) && b(statement!.comment)) {
      String comment = statement.comment!;
      // DEFER: The multi-line Tree Tile makes the branch not point to the icon.
      commentWidget = InputDecorator(
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          labelText: 'Comment',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(1.0)),
        ),
        child: Linky(comment),
        // child: TextField(
        //     readOnly: true, maxLines: null, controller: TextEditingController()..text = comment)
      );
    }

    Widget titleWidget =
        isStatement ? _StatementTitle(statement!) : SubjectTitle(subjectNode.subject);

    Widget? statementDesc;
    if (isStatement) {
      final ContentVerb verb = statement!.verb;
      StringBuffer buf = StringBuffer();
      if (verb == ContentVerb.rate) {
        if (b(statement.recommend)) {
          buf.write('recommended ');
        }
        if (b(statement.dismiss)) {
          buf.write('dismissed ');
        }
      } else {
        buf.write('  ${verb.pastTense}: ');
      }
      Color textColor =
          !ContentBase().isRejected(subjectNode.subject.token) ? Colors.black : Colors.pink;
      statementDesc = Text('  ${buf.toString()}', style: TextStyle(color: textColor));
    }

    // Computed but not displayed: PropType.recentActivity
    Map<PropType, Prop> props =
        subjectNode.computeProps([PropType.recommend, PropType.numComments]);
    List<Widget> propWidgets = [];
    propWidgets.add(props[PropType.recommend]!.getWidget());
    propWidgets.add(props[PropType.numComments]!.getWidget());

    Json? json;
    if (Prefs.showStatements.value) {
      json = subjectNode.subject.json;
    }

    return TreeIndentation(
        entry: widget.entry,
        guide: const IndentGuide.connectingLines(indent: 48),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Tooltip(
                  message: subjectTooltip ?? '',
                  child: FolderButton(
                      icon: closedIcon,
                      openedIcon: openedIcon,
                      closedIcon: closedIcon,
                      isOpen: widget.entry.hasChildren ? widget.entry.isExpanded : null,
                      onPressed: widget.entry.hasChildren ? widget.onTap : null),
                ),
                _ReactIcon(subjectNode.subject),
                const SizedBox(width: 8),
                ...propWidgets,
                if (Prefs.showStatements.value) JSWidget(json!),
                titleWidget,
                if (b(statementDesc)) statementDesc!,
              ]),
              if (b(commentWidget)) commentWidget!,
            ])));
  }
}

class _ReactIcon extends StatefulWidget {
  final Jsonish subject;

  const _ReactIcon(this.subject, {super.key});

  @override
  State<StatefulWidget> createState() {
    return _ReactIconState();
  }
}

// Arg.. I tried listening to ContentBase but it didn't work, and
// I added this Kludge so that ContentBase calls this directly.
class ReactIconStateClearHelper {
  static void clear() {
    _ReactIconState.marked1 = null;
    _ReactIconState.marked2 = null;
  }
}

class _ReactIconState extends State<_ReactIcon> {
  static _ReactIconState? marked1;
  static _ReactIconState? marked2;

  @override
  Widget build(BuildContext context) {
    assert(ContentBase().ready);
    // same: assert(Comp.compsReady([ContentBase()]));

    bool iReacted = ContentBase().findMyStatements(widget.subject.token).isNotEmpty;
    Color color = (this == marked1 || this == marked2) ? Colors.lightBlue : Colors.black;
    IconData iconData = iReacted ? Icons.mark_chat_read : Icons.mark_chat_read_outlined;
    return GestureDetector(
      onTapDown: (details) {
        showPopUpMenuAtTap(context, details);
      },
      child: IconButton(
          // splashRadius: 0.0001,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 22, maxWidth: 22),
          icon: Icon(iconData, color: color),
          tooltip: 'React to the subject of this row',
          onPressed: null),
    );
  }

  void showPopUpMenuAtTap(BuildContext context, TapDownDetails details) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy,
          details.globalPosition.dx, details.globalPosition.dy),
      items: [
        const PopupMenuItem<String>(value: 'react', child: Text('react')),
        const PopupMenuItem<String>(value: 'relate', child: Text('relate')),
      ],
      elevation: 8.0,
    ).then((value) async {
      if (value == 'react') {
        await rate(widget.subject, context);
      } else if (value == 'relate') {
        handleRelateClick(context);
      }
    });
  }

  /// Relate 2 things.
  /// - Click on the first to select it.
  /// - Click on it again to un-select it.
  /// - Click on the second to bring up dialog to relate the two.
  /// - Dialog should come up, and the selection of both should be visible.
  /// - After dismissing the dialog (relate / equate or cancel), the selections should be cleared.
  void handleRelateClick(BuildContext context) async {
    if (marked1 == null) {
      assert(marked2 == null);
      marked1 = this;
      setState(() {});
    } else if (marked1 == this) {
      assert(marked2 == null);
      marked1 = null;
      setState(() {});
    } else {
      assert(marked1 != null);
      assert(marked2 == null);
      marked2 = this;
      setState(() {});
      _ReactIconState? tmp1 = marked1;
      _ReactIconState? tmp2 = marked2;
      await relate(marked1!.widget.subject, marked2!.widget.subject, context);
      ReactIconStateClearHelper.clear(); // in case of cancel
      tmp1!.setState(() {});
      tmp2!.setState(() {});
    }
  }
}

class _StatementTitle extends StatelessWidget {
  final ContentStatement statement;

  const _StatementTitle(
    this.statement, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Json jsonKey = statement.json['I'];
    String token = Jsonish(jsonKey).token;
    String nerdName = KeyLabels().labelKey(FollowNet().delegate2oneofus[token]!)!;
    var time = statement.time;
    return InkWell(
        onTap: () {
          NetTreeView.show(context, highlightToken: token);
        },
        child: Row(children: [
          Text(nerdName, style: linkStyle),
          Tooltip(
            message: formatUiDatetime(time),
            child: Text('@${formatUiDate(time)}'),
          ),
        ]));
  }
}

class SubjectTitle extends StatelessWidget {
  final Jsonish subject;

  const SubjectTitle(
    this.subject, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    String url;
    if (subject.json.containsKey('url')) {
      url = subject.json['url'];
    } else {
      String out = 'https://www.google.com/search?q=${subject.json.values.join(' ')}';
      url = out;
    }

    return Flexible(
        child: ClipRect(
            child: InkWell(
                onTap: () {
                  myLaunchUrl(url);
                },
                child: Text((subject.json['title']),
                    style: const TextStyle(
                        color: Colors.blueAccent, decoration: TextDecoration.underline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis))));
  }
}
