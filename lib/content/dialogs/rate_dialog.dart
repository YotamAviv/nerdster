import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/dialogs/on_off_icon.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

/// DONE:
/// - Don't allow me to clear and censor (must do one at a time).
/// - Don't allow me to censor if I have a priorStatement (I should clear my statement instead).
/// - Don't allow me to censor my statement
/// - Okay not enabled unless changed.
/// - Don't allow rating nothing.
/// - All controls disabled when censor or clear pressed (other than unpressing erase or censor).

Future<Json?> rateDialog(BuildContext context, Jsonish subject, ContentStatement? priorStatement) {
  return showDialog<Json>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
          child: Padding(
              padding: const EdgeInsets.all(15),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 700,
                    maxHeight: 500,
                  ),
                  child: RateBody(subject, priorStatement)))));
}

class RateBody extends StatefulWidget {
  final Jsonish subject;
  final ContentStatement? priorStatement;

  const RateBody(this.subject, this.priorStatement, {super.key});

  @override
  State<StatefulWidget> createState() => RateBodyState();
}

class RateBodyState extends State<RateBody> {
  TextEditingController commentController = TextEditingController();
  ValueNotifier<bool> recommend = ValueNotifier(false);
  ValueNotifier<bool> dis = ValueNotifier(false);
  ValueNotifier<bool> erase = ValueNotifier(false);
  ValueNotifier<bool> censor = ValueNotifier(false);

  ValueNotifier<bool> okEnabled = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    setToPrior();
    commentController.addListener(listener);
  }

  void listener() {
    okEnabled.value = !compareToPrior || censor.value;
    if (bAllFieldsClear && b(widget.priorStatement)) {
      erase.value = true;
    }
    setState(() {});
  }

  void setToPrior() {
    if (b(widget.priorStatement)) {
      recommend.value = b(widget.priorStatement!.recommend);
      dis.value = b(widget.priorStatement!.dismiss);
      commentController.text = widget.priorStatement!.comment ?? '';
    }
  }

  bool get compareToPrior {
    if (b(widget.priorStatement)) {
      return recommend.value == b(widget.priorStatement!.recommend) &&
          dis.value == b(widget.priorStatement!.dismiss) &&
          censor.value == (widget.priorStatement!.verb == ContentVerb.censor) &&
          commentController.text == (widget.priorStatement!.comment ?? '');
    } else {
      return bAllFieldsClear;
    }
  }

  void clearFields() {
    recommend.value = false;
    dis.value = false;
    commentController.text = '';
  }

  bool get bAllFieldsClear => !recommend.value && !dis.value && commentController.text.isEmpty;

  Future<void> okHandler() async {
    Json json;
    if (erase.value) {
      assert(!censor.value);
      json = ContentStatement.make(
          signInState.signedInDelegatePublicKeyJson!, ContentVerb.clear, widget.subject.token);
    } else if (censor.value) {
      assert(!erase.value);
      assert(bAllFieldsClear);
      json = ContentStatement.make(
          signInState.signedInDelegatePublicKeyJson!, ContentVerb.censor, widget.subject.token);
    } else {
      bool? recommendX;
      if (recommend.value) {
        recommendX = true;
      }
      bool? dismiss;
      if (dis.value) {
        dismiss = true;
      }
      String? comment;
      if (commentController.text.isNotEmpty) {
        comment = commentController.text;
      }

      // When rating a statement, use the token instead of the entire statement.
      var subject = (widget.subject.containsKey('statement'))
          ? widget.subject.token
          : widget.subject.json;

      json = ContentStatement.make(
          signInState.signedInDelegatePublicKeyJson!, ContentVerb.rate, subject,
          recommend: recommendX, dismiss: dismiss, comment: comment);
    }
    print(Jsonish(json).ppJson);
    Navigator.pop(context, json);
  }

  void eraseCallback() {
    if (erase.value || censor.value) {
      clearFields();
    } else {
      if (b(widget.priorStatement)) {
        setToPrior();
      }
      // There's no need to clearFields; they should have already been cleared since I'm
      // un-pressing either the erase or clear button.
    }
    listener();
  }

  void censorCallback() {
    eraseCallback();
  }

  @override
  Widget build(BuildContext context) {
    // check if subject is my statement
    bool subjectIsMyStatement = false;
    if (b(signInState.signedInDelegate)) {
      try {
        Statement cs = Statement.make(widget.subject);
        subjectIsMyStatement = followNet.delegate2oneofus[cs.iToken] ==
            followNet.delegate2oneofus[signInState.signedInDelegate!];
      } catch (e) {}
    }

    // print(b(widget.priorStatement));
    // print(b(signInState.signedInDelegate));
    // if (b(widget.priorStatement) && b(signInState.signedInDelegate)) {
    //   print(
    //       '${followNet.delegate2oneofus[widget.priorStatement!.iToken]} == ${followNet.delegate2oneofus[signInState.signedInDelegate!]}');
    // }

    bool editingEnabled = !censor.value && !erase.value;

    TextStyle subjectStyle = !censor.value
        ? GoogleFonts.courierPrime(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black)
        : GoogleFonts.courierPrime(
            decoration: TextDecoration.lineThrough,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.black);

    OnOffIcon recommendButton = OnOffIcon(
      recommend,
      Icons.thumb_up,
      Icons.thumb_up_outlined,
      tooltipText: 'Recommend',
      text: 'Recommend',
      color: Colors.green,
      callback: listener,
      disabled: !editingEnabled,
    );
    OnOffIcon disButton = OnOffIcon(
      dis,
      Icons.swipe_left,
      Icons.swipe_left_outlined,
      tooltipText: 'Dismiss (I don\'t care to see this again)',
      text: 'Dismiss',
      color: Colors.brown,
      callback: listener,
      disabled: !editingEnabled,
    );
    OnOffIcon eraseButton = OnOffIcon(
      erase,
      Icons.cancel,
      Icons.cancel_outlined,
      tooltipText: '''Clear my reaction''',
      text: 'Clear my reaction',
      disabled: !b(widget.priorStatement),
      callback: eraseCallback,
    );
    String censorTooltip;
    if (subjectIsMyStatement) {
      censorTooltip =
          '''The subject here is your own statement. Click on the subject of this subject (its parent), and clear your reaction there instead.''';
    } else if (b(widget.priorStatement)) {
      censorTooltip = 'You must clear your own reaction first in order to censor';
    } else {
      censorTooltip = 'Censor this subject for everybody (who cares)';
    }
    OnOffIcon censorButton = OnOffIcon(
      censor,
      Icons.delete,
      Icons.delete_outlined,
      tooltipText: censorTooltip,
      text: 'Censor!',
      color: Colors.red,
      disabled: b(widget.priorStatement) || subjectIsMyStatement,
      callback: eraseCallback,
    );

    Widget warning = const SizedBox(width: 120.0);
    if (widget.subject['statement'] == kNerdsterType) {
      warning = SizedBox(
        width: 120.0,
        child: Tooltip(
            message:
                '''Subjects (ex. {books, articles, or movies}) just exist, but Nerd'ster user reactions (ex. {rate, comment, dis}) are fleeting.
A user can have one disposition on a subject, and so any newer reaction by him (including an edit to a comment) will overwrite his earlier one,
which will make your reaction to his reaction lost.''',
            child: Text('reacting to a reaction?', style: linkStyle)),
      );
    }

    ScrollController scrollController = ScrollController();
    return ListView(shrinkWrap: true, children: [
      InputDecorator(
          decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              labelText: 'Subject',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0))),
          child: Scrollbar(
              controller: scrollController,
              trackVisibility: true,
              thumbVisibility: true,
              child: TextField(
                  scrollController: scrollController,
                  controller: TextEditingController()
                    ..text = Prefs.keyLabel.value
                        ? encoder.convert(keyLabels.show(widget.subject))
                        : widget.subject.ppJson,
                  maxLines: 10,
                  readOnly: true,
                  style: subjectStyle))),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          recommendButton,
          disButton,
          eraseButton,
          censorButton,
        ],
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

// -- Copy paste this into main() to just show the dialog for development. --
// Json iKey = {'iKey': 1};
// Json subject = {'hi': 'there'};
// ContentStatement prior = ContentStatement(Jsonish(
//     ContentStatement.make(iKey, ContentVerb.rate, subject, comment: 'my comment', recommend: true)));
// SignInState.init('dummy');
// runApp(MaterialApp(
//     home: Scaffold(
//         body: SafeArea(
//   child: RateBody(Jsonish(subject), prior),
// ))));
// return;
// -- Copy paste this into main() to just show the dialog for development. --
