import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/util_ui.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/model.dart';

import '../content/content_statement.dart';
import '../content/dialogs/on_off_icon.dart';
import '../content/dialogs/on_off_icons.dart';
import '../oneofus/statement.dart';
import '../oneofus/util.dart';
import '../singletons.dart';
import 'subject_view.dart';

enum RateIntent { like, dislike, dismiss, comment, censor, clear, none }

class V2RateDialog extends StatefulWidget {
  final SubjectAggregation aggregation;
  final V2FeedModel model;
  final RateIntent intent;
  final bool? initialLike;
  final String? initialDismiss;

  const V2RateDialog({
    super.key,
    required this.aggregation,
    required this.model,
    this.intent = RateIntent.none,
    this.initialLike,
    this.initialDismiss,
  });

  static Future<ContentStatement?> show(
    BuildContext context,
    SubjectAggregation aggregation,
    V2FeedController controller, {
    RateIntent intent = RateIntent.none,
    bool? initialLike,
    String? initialDismiss,
  }) async {
    final model = controller.value;
    if (model == null) return null;

    if (!bb(await checkSignedIn(context, trustGraph: model.trustGraph))) return null;

    final result = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => V2RateDialog(
        aggregation: aggregation,
        model: model,
        intent: intent,
        initialLike: initialLike,
        initialDismiss: initialDismiss,
      ),
    );

    if (result != null) {
      return (await controller.push(result, signInState.signer!, context: context)) as ContentStatement?;
    }
    return null;
  }

  @override
  State<V2RateDialog> createState() => _V2RateDialogState();
}

class _V2RateDialogState extends State<V2RateDialog> {
  late ValueNotifier<bool?> like;
  late ValueNotifier<String?> dis;
  late ValueNotifier<bool> censor;
  late ValueNotifier<bool> erase;
  late ValueNotifier<bool> okEnabled;
  late TextEditingController commentController;
  ContentStatement? priorStatement;

  @override
  void initState() {
    super.initState();

    // Find prior statement by this user for this literal token
    final token = widget.aggregation.token;
    final List<ContentStatement> myLiteralStatements =
        List.from(widget.model.aggregation.myLiteralStatements[token] ?? []);

    Statement.validateOrderTypes(myLiteralStatements);

    priorStatement = myLiteralStatements.isEmpty ? null : myLiteralStatements.first;

    like = ValueNotifier(widget.initialLike ?? priorStatement?.like);
    dis = ValueNotifier(widget.initialDismiss ?? priorStatement?.dismiss);
    censor = ValueNotifier(priorStatement?.censor ?? false);
    erase = ValueNotifier(false);
    okEnabled = ValueNotifier(false);
    commentController = TextEditingController(text: priorStatement?.comment ?? '');

    switch (widget.intent) {
      case RateIntent.like:
        like.value = (like.value == true ? null : true);
        break;
      case RateIntent.dislike:
        like.value = (like.value == false ? null : false);
        break;
      case RateIntent.dismiss:
        // Toggle between null and snooze
        if (dis.value == null) {
          dis.value = 'snooze';
        } else if (dis.value == 'snooze') {
          dis.value = 'forever';
        } else {
          dis.value = null;
        }
        break;
      case RateIntent.comment:
        break;
      case RateIntent.censor:
        censor.value = !censor.value;
        break;
      case RateIntent.clear:
        erase.value = true;
        clearFields();
        break;
      case RateIntent.none:
        break;
    }

    commentController.addListener(listener);
    listener();
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
    super.dispose();
  }

  void listener() {
    // Allow re-submit if it's a snooze (to re-snooze woken items)
    bool isReSnooze = dis.value == 'snooze' && priorStatement?.dismiss == 'snooze';
    okEnabled.value = !compareToPrior || censor.value || isReSnooze;

    if (b(priorStatement)) {
      erase.value = bAllFieldsClear;
    }
    if (mounted) setState(() {});
  }

  void eraseListener() {
    if (erase.value) {
      clearFields();
    } else {
      if (b(priorStatement)) setToPrior();
    }
    listener();
  }

  void setToPrior() {
    if (b(priorStatement)) {
      like.value = priorStatement!.like;
      dis.value = priorStatement!.dismiss;
      censor.value = b(priorStatement!.censor);
      commentController.text = priorStatement!.comment ?? '';
    }
  }

  bool get compareToPrior {
    if (b(priorStatement)) {
      return like.value == priorStatement!.like &&
          dis.value == priorStatement!.dismiss &&
          censor.value == b(priorStatement!.censor) &&
          commentController.text == (priorStatement!.comment ?? '');
    } else {
      return bAllFieldsClear;
    }
  }

  void clearFields() {
    like.value = null;
    dis.value = null;
    censor.value = false;
    commentController.text = '';
  }

  bool get bAllFieldsClear =>
      !b(like.value) && dis.value == null && !censor.value && commentController.text.isEmpty;

  bool? trueOrNull(bool b) => b ? true : null;

  void _onOk() {
    if (signInState.delegatePublicKeyJson == null) return;

    final Json i = signInState.delegatePublicKeyJson!;
    String? comment = commentController.text.isNotEmpty ? commentController.text : null;
    ContentVerb verb;
    if (erase.value) {
      verb = ContentVerb.clear;
    } else {
      verb = ContentVerb.rate;
    }

    final json = ContentStatement.make(
      i,
      verb,
      widget.aggregation.subject,
      recommend: like.value,
      dismiss: dis.value,
      censor: trueOrNull(censor.value),
      comment: comment,
    );
    Navigator.pop(context, json);
  }

  @override
  Widget build(BuildContext context) {
    final rawSubject = widget.aggregation.subject;
    final isMap = true;
    final isStatement = isMap && rawSubject.containsKey('statement');

    bool subjectIsMyStatement = false;
    if (isStatement) {
      final stmt = Statement.make(Jsonish(Map<String, dynamic>.from(rawSubject)));
      final String myIdentity = signInState.identity;
      if (stmt is TrustStatement) {
        subjectIsMyStatement = (stmt.iKey.value == myIdentity);
      } else if (stmt is ContentStatement) {
        subjectIsMyStatement =
            (widget.model.delegateResolver.getIdentityForDelegate(stmt.iKey)?.value ==
                myIdentity);
      }
    }

    const Map<Object, (IconData, IconData)> key2icons = {
      true: (Icons.thumb_up, Icons.thumb_up_outlined),
      false: (Icons.thumb_down, Icons.thumb_down_outlined)
    };

    OnOffIcons likeButton = OnOffIcons(like, key2icons,
        text: 'Like',
        tooltipText: 'Like or dislike',
        color: Colors.green,
        key2colors: const {true: Colors.green, false: Colors.red},
        callback: listener);

    Widget disButton = _DismissToggle(
      notifier: dis,
      callback: listener,
    );

    String censorTooltip;
    if (subjectIsMyStatement) {
      censorTooltip =
          'The subject here is your own statement. Clear your rating on its parent instead.';
    } else {
      censorTooltip = 'Censor this subject for everybody (who cares)';
    }
    OnOffIcon censorButton = OnOffIcon(censor, Icons.delete, Icons.delete_outlined,
        text: 'Censor!',
        tooltipText: censorTooltip,
        color: Colors.red,
        disabled: subjectIsMyStatement,
        callback: listener);
    OnOffIcon eraseButton = OnOffIcon(erase, Icons.cancel, Icons.cancel_outlined,
        text: 'Clear',
        tooltipText: 'Clear (erase) my rating',
        disabled: !b(priorStatement),
        callback: eraseListener);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rate & Comment',
              style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                      labelText: 'Subject',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0)),
                    ),
                    child: V2SubjectView(
                      subject: rawSubject,
                      strikethrough: censor.value,
                      labeler: widget.model.labeler,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [likeButton, disButton, censorButton, eraseButton],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    enabled: !erase.value,
                    controller: commentController,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...\n#hashtag',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    autofocus: widget.intent == RateIntent.comment,
                  ),
                  if (isStatement) ...[
                    const SizedBox(height: 12),
                    const Tooltip(
                      message:
                          'A user can have only one disposition on a subject, so any newer rating will overwrite his earlier one.',
                      child: Text(
                        'rating a rating?',
                        style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end, // or center/spaceAround
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: okEnabled,
                builder: (context, enabled, _) => ElevatedButton(
                  onPressed: enabled ? _onOk : null,
                  child: const Text('Publish'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}


class _DismissToggle extends StatelessWidget {
  final ValueNotifier<String?> notifier;
  final bool disabled;
  final VoidCallback? callback;

  const _DismissToggle({
    required this.notifier,
    this.disabled = false,
    this.callback,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: notifier,
      builder: (context, value, _) {
        IconData icon;
        Color? color;
        String tooltip;

        if (value == 'snooze') {
          icon = Icons.snooze;
          color = Colors.brown;
          tooltip = 'Snoozed (hidden until new activity)';
        } else if (value == 'forever') {
          icon = Icons.swipe_left;
          color = Colors.brown;
          tooltip = 'Dismissed forever';
        } else {
          icon = Icons.swipe_left_outlined;
          color = null; // Default icon color (usually grey/black)
          tooltip = 'Dismiss';
        }

        TextStyle? textStyle = disabled ? hintStyle : null;

        return Tooltip(
          message: tooltip,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSmall.value) Text('Dismiss', style: textStyle),
              IconButton(
                icon: Icon(icon),
                color: color,
                onPressed: disabled
                    ? null
                    : () {
                        if (value == null) {
                          notifier.value = 'snooze';
                        } else if (value == 'snooze') {
                          notifier.value = 'forever';
                        } else {
                          notifier.value = null;
                        }
                        callback?.call();
                      },
              ),
            ],
          ),
        );
      },
    );
  }
}
