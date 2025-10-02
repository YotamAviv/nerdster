import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/comment_widget.dart';
import 'package:nerdster/content/content_bar.dart';
import 'package:nerdster/content/content_base.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/content_tree_node.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/content/props.dart';
import 'package:nerdster/js_widget.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

const (IconData, IconData) statementIconPair = (Icons.attachment_outlined, Icons.attachment);

class ContentTile extends StatefulWidget {
  const ContentTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final TreeEntry<ContentTreeNode> entry;
  final VoidCallback onTap;

  @override
  State<StatefulWidget> createState() {
    return _ContentTileState();
  }
}

const space = SizedBox(width: 4);

class _ContentTileState extends State<ContentTile> {
  Icon relateIcon = const Icon(Icons.balance);

  @override
  initState() {
    super.initState();
    Setting.get<bool>(SettingType.showCrypto).addListener(listener);
  }

  @override
  dispose() {
    Setting.get<bool>(SettingType.showCrypto).removeListener(listener);
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
    // assert(contentBase.ready); // Witenessed, happens often with demo "delegateMerge"
    if (!contentBase.ready) return Text('...');

    final ContentTreeNode subjectNode = widget.entry.node;

    final bool isStatement = subjectNode.subject.containsKey('statement');
    ContentStatement? statement;
    (IconData, IconData) iconPair;
    if (isStatement) {
      statement = ContentStatement(subjectNode.subject);
      iconPair = statementIconPair;
    } else {
      iconPair = ContentType.values.byName(subjectNode.subject['contentType']).iconDatas;
    }

    String rowTooltip = "Click to expand statements about this subject";
    Color? iconColor;
    if (subjectNode.equivalent) {
      iconColor = Colors.lightGreen;
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
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            labelText: 'Comment',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(5))),
        child: CommentWidget(
          text: comment,
          onHashtagTap: (hashtag, context) {
            if (Setting.get(SettingType.tag).value != hashtag) {
              Setting.get(SettingType.tag).value = hashtag;
              tagFlashNotifier.value = true;
              Future.delayed(Duration.zero, () {
                tagFlashNotifier.value = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tag $hashtag selected.')),
              );
            }
          },
        ),
      );
    }

    Widget titleWidget =
        isStatement ? _StatementTitle(statement!) : SubjectTitle(subjectNode.subject);

    Widget? statementDesc;
    if (isStatement) {
      final ContentVerb verb = statement!.verb;
      Color textColor =
          !contentBase.isRejected(subjectNode.subject.token) ? Colors.black : Colors.pink;
      // DEFER: Get icons, colors, and tooltips from a common place with [RateDialog].
      statementDesc = Row(
        children: [
          space,
          Text(style: TextStyle(color: textColor), verb.pastTense),
          space,
          if (b(statement.like))
            (statement.like!
                ? Tooltip(
                    message: 'Like',
                    child: Icon(color: Colors.green, Icons.thumb_up),
                  )
                : Tooltip(
                    message: 'Dislike',
                    child: Icon(color: Colors.green, Icons.thumb_down),
                  )),
          if (b(statement.dismiss))
            Tooltip(message: 'Dismiss', child: Icon(color: Colors.brown, Icons.swipe_left)),
          if (b(statement.censor))
            Tooltip(
              message: 'Censor',
              child: Icon(color: Colors.red, Icons.delete),
            ),
        ],
      );
    }

    // Computed but not displayed: PropType.recentActivity
    Map<PropType, Prop> props = subjectNode.computeProps([PropType.like, PropType.numComments]);
    List<Widget> propWidgets = [];
    propWidgets.add(props[PropType.like]!.getWidget());
    propWidgets.add(props[PropType.numComments]!.getWidget());

    return TreeIndentation(
        entry: widget.entry,
        guide: const IndentGuide.connectingLines(indent: 92),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
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
                if (Setting.get<bool>(SettingType.showCrypto).value) JSWidget(subjectNode.subject),
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

/// Having all _ReactIcons listen to this, works but is wasteful, and so:
/// Rep invariant:
/// - only selected the widgets should be listening
///
// Arg.. I tried listening to ContentBase but it didn't work, and
// I added this Kludge so that ContentBase calls this directly.
class ReactIconSelection extends ChangeNotifier {
  static final ReactIconSelection _singleton = ReactIconSelection._internal();
  factory ReactIconSelection() => _singleton;
  ReactIconSelection._internal();

  List<Jsonish> selected = [];

  void clear() {
    _singleton.selected.clear();
    notifyListeners();
  }

  void toggle(Jsonish j) {
    selected.contains(j) ? selected.remove(j) : selected.add(j);
    assert(selected.length <= 2);
    notifyListeners();
  }
}

final ReactIconSelection reactIconSelection = ReactIconSelection();

class _ReactIconState extends State<_ReactIcon> {
  @override
  initState() {
    super.initState();
    if (reactIconSelection.selected.contains(widget.subject)) {
      reactIconSelection.addListener(listener);
    }
  }

  @override
  dispose() {
    // Just in case, could check if selected but that'd cost the same
    reactIconSelection.removeListener(listener);
    super.dispose();
  }

  void listener() {
    setState(() {});
    if (!reactIconSelection.selected.contains(widget.subject)) {
      reactIconSelection.removeListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) {
    // assert(contentBase.ready); // Witenessed, happens often with demo "delegateMerge"
    if (!contentBase.ready) return Text('...');

    IconData iconData;
    bool iReacted = contentBase.isReacted(widget.subject.token);
    bool isMarked = reactIconSelection.selected.contains(widget.subject);
    Color color = !iReacted ? linkColor : linkColorAlready;
    // CONSIDER: List<Shadow>? shadows = !iReacted ? null : <Shadow>[Shadow(color: color, blurRadius: 5.0)];
    List<Shadow>? shadows;
    iconData = isMarked ? Icons.mark_chat_read : Icons.mark_chat_read_outlined;
    return GestureDetector(
      onTap: () {
        rate(widget.subject, context);
        reactIconSelection.clear();
      },
      onDoubleTap: () => handleRelateClick(context),
      child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 22, maxWidth: 22),
          icon: Icon(iconData, color: color, shadows: shadows),
          tooltip: '''Click to rate (like, comment, dis, censor, or clear your previous rating)
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
    if (!bb(await checkSignedIn(context))) return;
    reactIconSelection.toggle(widget.subject);
    if (reactIconSelection.selected.contains(widget.subject)) {
      reactIconSelection.addListener(listener);
    }
    listener();
    if (reactIconSelection.selected.length == 2) {
      await relate(reactIconSelection.selected[0], reactIconSelection.selected[1], context);
      reactIconSelection.clear();
    }
  }
}

class _StatementTitle extends StatelessWidget {
  final ContentStatement statement;
  const _StatementTitle(this.statement);
  @override
  Widget build(BuildContext context) {
    String token = statement.iToken;
    String label = keyLabels.labelKey(followNet.delegate2oneofus[token]!)!;
    var time = statement.time;
    return InkWell(
        onTap: () => NetTreeView.show(context, highlightToken: token),
        child: Row(children: [
          Text(label, style: linkStyle),
          Tooltip(message: formatUiDatetime(time), child: Text('@${formatUiDate(time)}')),
        ]));
  }
}

class SubjectTitle extends StatelessWidget {
  final Jsonish subject;

  const SubjectTitle(this.subject, {super.key});

  @override
  Widget build(BuildContext context) {
    String url;
    if (subject.containsKey('url')) {
      url = subject['url'];
    } else {
      String out = 'https://www.google.com/search?q=${subject.values.join(' ')}';
      url = out;
    }

    ContentType contentType = ContentType.values.byName(subject['contentType']);
    String? lanyap;
    // WEIRD: Switching on the enum didn't work, always ended at default.
    switch (contentType.name) {
      case 'article':
        try {
          lanyap = Uri.parse(subject['url']).host;
        } catch (e) {
          print(e);
        }
        break;
      case 'book':
        lanyap = subject['author'];
        break;
      case 'movie':
        lanyap = subject['year'];
        break;
      case 'album':
        lanyap = subject['artist'];
        break;
      default:
      // print(contentType);
    }

    String title = subject['title'];
    String message = b(lanyap) ? '($lanyap) $title' : title;
    return Flexible(
        child: Tooltip(
            message: message,
            child: ClipRect(
                child: InkWell(
                    onTap: () => myLaunchUrl(url, context),
                    child: Text(title,
                        style: linkStyle, maxLines: 1, overflow: TextOverflow.ellipsis)))));
  }
}
