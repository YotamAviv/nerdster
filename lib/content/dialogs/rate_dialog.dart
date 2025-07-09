import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/content/dialogs/on_off_icon.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

/// How nerdy?
/// There may be compelling reasons to
/// - recommend and dis (it's good, but I've seen it)
/// - censor and dis and comment (censorship might be disabled)
/// - censor and recommened (good porn)
///
/// There are no compelling reasons to
/// - censor your own statement (just clear it)
/// - clear and any other thing (recommend, dis, censor, comment)
///
/// Nerdy seems straight forward, and so:
/// - Don't allow me to clear and any other thing (recommend, dis, censor, comment)
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
                child: Padding(
                    padding: const EdgeInsets.all(15),
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
  ValueNotifier<bool> recommend = ValueNotifier(false);
  ValueNotifier<bool> dis = ValueNotifier(false);
  ValueNotifier<bool> censor = ValueNotifier(false);
  ValueNotifier<bool> erase = ValueNotifier(false);
  ValueNotifier<bool> okEnabled = ValueNotifier(false);
  ValueNotifier<bool> translate = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    setToPrior();
    commentController.addListener(listener);
  }

  @override
  void dispose() {
    commentController.removeListener(listener);
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
      recommend.value = b(widget.priorStatement!.recommend);
      dis.value = b(widget.priorStatement!.dismiss);
      censor.value = b(widget.priorStatement!.censor);
      // TODO: clear?
      commentController.text = widget.priorStatement!.comment ?? '';
    }
  }

  bool get compareToPrior {
    if (b(widget.priorStatement)) {
      return recommend.value == b(widget.priorStatement!.recommend) &&
          dis.value == b(widget.priorStatement!.dismiss) &&
          censor.value == b(widget.priorStatement!.censor) &&
          commentController.text == (widget.priorStatement!.comment ?? '');
    } else {
      return bAllFieldsClear;
    }
  }

  void clearFields() {
    recommend.value = false;
    dis.value = false;
    censor.value = false;
    commentController.text = '';
  }

  bool get bAllFieldsClear =>
      !recommend.value && !dis.value && !censor.value && commentController.text.isEmpty;

  Future<void> okHandler() async {
    final Json i = signInState.signedInDelegatePublicKeyJson!;
    String? comment = commentController.text.isNotEmpty ? commentController.text : null;
    ContentVerb verb;
    if (erase.value) {
      assert(bAllFieldsClear);
      assert(!recommend.value);
      assert(!dis.value);
      assert(!censor.value);
      assert(!b(comment));
      verb = ContentVerb.clear;
    } else {
      assert(!erase.value);
      verb = ContentVerb.rate;
    }

    var subject;
    if (verb == ContentVerb.clear || censor.value) {
      // For clear or censor, use the token instead of the entire subject.
      subject = widget.subject.token;
    } else {
      assert(verb == ContentVerb.rate);
      // When rating a statement, use the token instead of the entire statement.
      subject =
          (widget.subject.containsKey('statement')) ? widget.subject.token : widget.subject.json;
    }

    bool? recommendX = recommend.value ? true : null;
    bool? disX = dis.value ? true : null;
    bool? censorX = censor.value ? true : null;
    Json json = ContentStatement.make(i, verb, subject,
        recommend: recommendX, dismiss: disX, censor: censorX, comment: comment);
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
          followNet.delegate2oneofus[signInState.signedInDelegate!];
    } catch (e) {
      // Probably not even a statement
    }

    bool editingEnabled = !erase.value;

    OnOffIcon recommendButton = OnOffIcon(recommend, Icons.thumb_up, Icons.thumb_up_outlined,
        tooltipText: 'Recommend',
        text: 'Recommend',
        color: Colors.green,
        callback: listener,
        disabled: !editingEnabled);
    OnOffIcon disButton = OnOffIcon(dis, Icons.swipe_left, Icons.swipe_left_outlined,
        tooltipText: 'Dismiss (I don\'t care to see this again)',
        text: 'Dismiss',
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
        tooltipText: censorTooltip,
        text: 'Censor!',
        color: Colors.red,
        disabled: subjectIsMyStatement || !editingEnabled,
        callback: listener);
    OnOffIcon eraseButton = OnOffIcon(erase, Icons.cancel, Icons.cancel_outlined,
        tooltipText: '''Clear (erase) my rating''',
        text: 'Clear',
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
                  translate: translate, strikethrough: censor.value))),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [recommendButton, disButton, censorButton, eraseButton],
      ),
      TextField(
        enabled: editingEnabled,
        decoration: const InputDecoration(
            hintText: "Comment", border: OutlineInputBorder(), hintStyle: hintStyle),
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
