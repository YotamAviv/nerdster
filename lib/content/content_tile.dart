import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/content/content_base.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/content_tree_node.dart';
import 'package:nerdster/content/props.dart';
import 'package:nerdster/js_widget.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

const (IconData, IconData) statementIconPair = (Icons.attachment_outlined, Icons.attachment);

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

  @override
  initState() {
    super.initState();
    Prefs.keyLabel.addListener(listener);
    Prefs.showStatements.addListener(listener);
    Prefs.showJson.addListener(listener);
  }

  @override
  dispose() {
    Prefs.keyLabel.removeListener(listener);
    Prefs.showStatements.removeListener(listener);
    Prefs.showJson.removeListener(listener);
    super.dispose();
  }

  listener() async {
    await contentBase.waitUntilReady();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(contentBase.ready);

    final ContentTreeNode subjectNode = widget.entry.node;

    final bool isStatement = subjectNode.subject.json.containsKey('statement');
    ContentStatement? statement;
    (IconData, IconData) iconPair;
    if (isStatement) {
      statement = ContentStatement(subjectNode.subject);
      iconPair = statementIconPair;
    } else {
      iconPair = ContentType.values.byName(subjectNode.subject.json['contentType']).iconDatas;
    }

    String rowTooltip = "Click to expand statements about this subject";
    Color? iconColor;
    if (subjectNode.equivalent) {
      iconColor = Colors.pink;
      rowTooltip = 'equivalent of parent';
    } else if (subjectNode.related) {
      iconColor = Colors.lightBlue;
      rowTooltip = 'related to parent';
    }

    Icon openedIcon = Icon(iconPair.$1, color: iconColor);
    Icon closedIcon = Icon(iconPair.$2, color: iconColor);
    if (iconColor != null) {
      openedIcon = Icon(iconPair.$1, color: iconColor);
      closedIcon = Icon(iconPair.$2, color: iconColor);
    } else {
      openedIcon = Icon(iconPair.$1);
      closedIcon = Icon(iconPair.$2);
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
          !contentBase.isRejected(subjectNode.subject.token) ? Colors.black : Colors.pink;
      statementDesc = Text('  ${buf.toString()}', style: TextStyle(color: textColor));
    }

    // Computed but not displayed: PropType.recentActivity
    Map<PropType, Prop> props =
        subjectNode.computeProps([PropType.recommend, PropType.numComments]);
    List<Widget> propWidgets = [];
    propWidgets.add(props[PropType.recommend]!.getWidget());
    propWidgets.add(props[PropType.numComments]!.getWidget());

    return TreeIndentation(
        entry: widget.entry,
        guide: const IndentGuide.connectingLines(indent: 80),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _ReactIcon(subjectNode.subject),
                Tooltip(
                  message: rowTooltip,
                  child: FolderButton(
                      icon: closedIcon,
                      openedIcon: openedIcon,
                      closedIcon: closedIcon,
                      color: linkColor,
                      isOpen: widget.entry.hasChildren ? widget.entry.isExpanded : null,
                      onPressed: widget.entry.hasChildren ? widget.onTap : null),
                ),
                const SizedBox(width: 8),
                ...propWidgets,
                if (Prefs.showJson.value) JSWidget(subjectNode.subject.json),
                titleWidget,
                if (b(statementDesc)) statementDesc!,
              ]),
              if (b(commentWidget)) commentWidget!,
            ])));
  }
}

class _ReactIcon extends StatefulWidget {
  final Jsonish subject;

  const _ReactIcon(this.subject);

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
    assert(contentBase.ready); // QUESTIONABLE

    Color color;
    IconData iconData;
    bool iReacted = contentBase.findMyStatements(widget.subject.token).isNotEmpty;
    bool isMarked = this == marked1 || this == marked2;
    color = !iReacted ? linkColor : linkColorAlready;
    iconData = isMarked ? Icons.mark_chat_read : Icons.mark_chat_read_outlined;
    return GestureDetector(
      onTap: () async {
        await rate(widget.subject, context);
      },
      onDoubleTap: () async {
        await handleRelateClick(context);
      },
      child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 22, maxWidth: 22),
          icon: Icon(iconData, color: color),
          tooltip: '''Click to rate (recommend, comment, dis, censor, or clear rating)
Double click to relate / equate''',
          onPressed: null),
    );
  }

  /// Relate 2 things.
  /// - Click on the first to select it.
  /// - Click on it again to un-select it.
  /// - Click on the second to bring up dialog to relate the two.
  /// - Dialog should come up, and the selection of both should be visible.
  /// - After dismissing the dialog (relate / equate or cancel), the selections should be cleared.
  Future<void> handleRelateClick(BuildContext context) async {
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
    String label = keyLabels.labelKey(followNet.delegate2oneofus[token]!)!;
    var time = statement.time;
    return InkWell(
        onTap: () {
          NetTreeView.show(context, highlightToken: token);
        },
        child: Row(children: [
          Text(label, style: linkStyle),
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
                    style: linkStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis))));
  }
}
