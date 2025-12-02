import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/dialogs/on_off_icon.dart';
import 'package:nerdster/content/dialogs/on_off_icons.dart';
import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

/// How nerdy?
/// There may be compelling reasons to
/// - like and dis (it's good, but I've seen it)
/// - censor and dis and comment (censorship might be disabled)
/// - censor and recommened (good porn)
///
/// There are no compelling reasons to
/// - censor your own statement (just clear it)
/// - clear and any other thing (like, dis, censor, comment)
///
/// Nerdy seems straight forward, and so:
/// - Don't allow me to clear and any other thing (like, dis, censor, comment)
///   - Do allow me to click on clear again to un-clear
/// - Don't allow me to censor my statement (I should clear my statement instead)
/// - Okay not enabled unless there are changes
/// - All controls disabled when clear pressed (click on clear again to un-clear)

Future<Json?> rateDialog(BuildContext context, Jsonish subject, ContentStatement? priorStatement) {
  double width = max(MediaQuery.of(context).size.width / 2, 700);
  return showDialog<Json>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final focusNode = FocusNode(); // Create a FocusNode
        // Dismiss with Escape key (code from AI, and questionable - see commented out sections). TODO: Use elsewhere.
        return KeyboardListener(
            focusNode: focusNode,
            autofocus: true,
            onKeyEvent: (event) {
              if (event.logicalKey == LogicalKeyboardKey.escape && event is KeyDownEvent) {
                Navigator.of(context).pop();
                // DEFER: Investigate: return KeyEventResult.handled;
              }
              // DEFER: Investigate: return KeyEventResult.ignored;
            },
            child: Dialog(
                shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
                child: Padding(
                    padding: kTallPadding,
                    child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: width, maxHeight: 500),
                        child: RateBody(subject, priorStatement)))));
      });
}

class RateBody extends StatefulWidget {
  final Jsonish subject;
  final ContentStatement? priorStatement;

  const RateBody(this.subject, this.priorStatement, {super.key});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<RateBody> {
  TextEditingController commentController = TextEditingController();
  ValueNotifier<bool?> like = ValueNotifier(null);
  ValueNotifier<bool> dis = ValueNotifier(false);
  ValueNotifier<bool> censor = ValueNotifier(false);
  ValueNotifier<bool> erase = ValueNotifier(false);
  ValueNotifier<bool> okEnabled = ValueNotifier(false);
  ValueNotifier<bool> interpret = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    setToPrior();
    commentController.addListener(listener);
  }

  @override
  void dispose() {
    commentController.removeListener(listener);
    commentController.dispose();
    like.dispose();
    dis.dispose();
    censor.dispose();
    erase.dispose();
    okEnabled.dispose();
    interpret.dispose();
    super.dispose();
  }

  void listener() {
    okEnabled.value = !compareToPrior || censor.value;
    if (bAllFieldsClear && b(widget.priorStatement)) {
      erase.value = true;
    }
    setState(() {});
  }

  void eraseListener() {
    if (erase.value) {
      clearFields();
    } else {
      if (b(widget.priorStatement)) setToPrior();
    }
    listener();
  }

  void setToPrior() {
    if (b(widget.priorStatement)) {
      like.value = widget.priorStatement!.like;
      dis.value = b(widget.priorStatement!.dismiss);
      censor.value = b(widget.priorStatement!.censor);
      commentController.text = widget.priorStatement!.comment ?? '';
    }
  }

  bool get compareToPrior {
    if (b(widget.priorStatement)) {
      return like.value == widget.priorStatement!.like &&
          dis.value == b(widget.priorStatement!.dismiss) &&
          censor.value == b(widget.priorStatement!.censor) &&
          commentController.text == (widget.priorStatement!.comment ?? '');
    } else {
      return bAllFieldsClear;
    }
  }

  void clearFields() {
    like.value = null;
    dis.value = false;
    censor.value = false;
    commentController.text = '';
  }

  bool get bAllFieldsClear =>
      !b(like.value) && !dis.value && !censor.value && commentController.text.isEmpty;

  bool? trueOrNull(bool b) => b ? true : null;

  Future<void> okHandler() async {
    final Json i = signInState.delegatePublicKeyJson!;
    String? comment = commentController.text.isNotEmpty ? commentController.text : null;
    ContentVerb verb;
    if (erase.value) {
      assert(bAllFieldsClear);
      assert(!b(like.value));
      assert(!dis.value);
      assert(!censor.value);
      assert(!b(comment));
      verb = ContentVerb.clear;
    } else {
      assert(!erase.value);
      verb = ContentVerb.rate;
    }

    Object subject;
    // For clear, censor, rate with dis, or rate statement:
    // use the subject token instead of the entire subject.
    if (verb == ContentVerb.clear ||
        censor.value ||
        (verb == ContentVerb.rate && dis.value) ||
        widget.subject.containsKey('statement')) {
      subject = widget.subject.token;
    } else {
      assert(verb == ContentVerb.rate);
      subject = widget.subject.json;
    }

    Json json = ContentStatement.make(i, verb, subject,
        recommend: like.value,
        dismiss: trueOrNull(dis.value),
        censor: trueOrNull(censor.value),
        comment: comment);
    print(Jsonish(json).ppJson);
    Navigator.pop(context, json);
  }

  @override
  Widget build(BuildContext context) {
    // check if subject is my statement
    bool subjectIsMyStatement = false;
    try {
      // Assume that subject is a statement, construct the Statement, and check if I'm its author.
      Statement temp = Statement.make(widget.subject);
      subjectIsMyStatement = followNet.delegate2oneofus[temp.iToken] ==
          followNet.delegate2oneofus[signInState.delegate!];
    } catch (e) {
      // Probably not even a statement
    }

    bool editingEnabled = !erase.value;

    const Map<Object, (IconData, IconData)> key2icons = {
      true: (Icons.thumb_up, Icons.thumb_up_outlined),
      false: (Icons.thumb_down, Icons.thumb_down_outlined)
    };
    OnOffIcons likeButton = OnOffIcons(like, key2icons,
        text: 'Like',
        tooltipText: 'Like or dislike',
        color: Colors.green,
        callback: listener,
        disabled: !editingEnabled);
    OnOffIcon disButton = OnOffIcon(dis, Icons.swipe_left, Icons.swipe_left_outlined,
        text: 'Dismiss',
        tooltipText: 'Dismiss (I don\'t care to see this again)',
        color: Colors.brown,
        callback: listener,
        disabled: !editingEnabled);
    String censorTooltip;
    if (subjectIsMyStatement) {
      censorTooltip =
          '''The subject here is your own statement. Click on the subject of this subject (its parent), and clear your rating there instead.''';
    } else {
      censorTooltip = 'Censor this subject for everybody (who cares)';
    }
    OnOffIcon censorButton = OnOffIcon(censor, Icons.delete, Icons.delete_outlined,
        text: 'Censor!',
        tooltipText: censorTooltip,
        color: Colors.red,
        disabled: subjectIsMyStatement || !editingEnabled,
        callback: listener);
    OnOffIcon eraseButton = OnOffIcon(erase, Icons.cancel, Icons.cancel_outlined,
        text: 'Clear',
        tooltipText: '''Clear (erase) my rating''',
        disabled: !b(widget.priorStatement),
        callback: eraseListener);

    Widget warning = const SizedBox(width: 120.0);
    if (widget.subject['statement'] == kNerdsterType) {
      warning = SizedBox(
        width: 120.0,
        child: Tooltip(
            message:
                '''Subjects (ex. {books, articles, or movies}) just exist, but Nerd'ster user ratings are fleeting.
A user can have only one disposition on a subject, and so any newer rating by him (including an edit to a comment) will overwrite his earlier one,
which will make your rating of his rating lost.''',
            child: Text('rating a rating?', style: linkStyle)),
      );
    }

    return ListView(shrinkWrap: true, children: [
      InputDecorator(
          decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              labelText: 'Subject',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0))),
          child: SizedBox(
              height: 200,
              child: JsonDisplay(widget.subject.json,
                  interpret: interpret, strikethrough: censor.value))),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [likeButton, disButton, censorButton, eraseButton],
      ),
      TextField(
        enabled: editingEnabled,
        decoration: const InputDecoration(hintText: '''Blah, blah, blah, ...
#hashtag, #hashtag''', border: OutlineInputBorder(), hintStyle: hintStyle),
        maxLines: 4,
        controller: commentController,
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 120),
          OkCancel(okHandler, 'Okay', okEnabled: okEnabled),
          warning,
        ],
      ),
    ]);
  }
}
