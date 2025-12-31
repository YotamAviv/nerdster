import 'package:flutter/material.dart';
import '../singletons.dart';
import '../content/content_statement.dart';
import '../oneofus/jsonish.dart';
import '../oneofus/util.dart';
import '../oneofus/json_display.dart';
import '../oneofus/statement.dart';
import '../content/dialogs/on_off_icon.dart';
import '../content/dialogs/on_off_icons.dart';
import '../util_ui.dart';
import 'model.dart';
import 'source_factory.dart';

enum RateIntent { like, dislike, dismiss, comment, censor, clear, none }

class V2RateDialog extends StatefulWidget {
  final SubjectAggregation aggregation;
  final V2FeedModel model;
  final RateIntent intent;

  const V2RateDialog({
    super.key,
    required this.aggregation,
    required this.model,
    this.intent = RateIntent.none,
  });

  static Future<void> show(
    BuildContext context,
    SubjectAggregation aggregation,
    V2FeedModel model, {
    RateIntent intent = RateIntent.none,
    VoidCallback? onRefresh,
  }) async {
    final result = await showDialog<Json>(
      context: context,
      builder: (context) => V2RateDialog(
        aggregation: aggregation,
        model: model,
        intent: intent,
      ),
    );

    if (result != null) {
      try {
        final writer = SourceFactory.getWriter(kNerdsterDomain, context: context);
        await writer.push(result, signInState.signer!);
        onRefresh?.call();
      } catch (e, stackTrace) {
        if (e.toString().contains('LGTM check failed')) return;
        debugPrint('V2RateDialog Error: $e\n$stackTrace');
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to post statement: $e'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  State<V2RateDialog> createState() => _V2RateDialogState();
}

class _V2RateDialogState extends State<V2RateDialog> {
  late ValueNotifier<bool?> like;
  late ValueNotifier<bool> dis;
  late ValueNotifier<bool> censor;
  late ValueNotifier<bool> erase;
  late ValueNotifier<bool> okEnabled;
  late ValueNotifier<bool> interpret;
  late TextEditingController commentController;
  ContentStatement? priorStatement;

  @override
  void initState() {
    super.initState();
    
    // Find prior statement by this user
    final myIdentity = signInState.identity;
    if (myIdentity != null) {
      try {
        priorStatement = widget.aggregation.statements.firstWhere(
          (s) => widget.model.labeler.getIdentityForToken(s.iToken) == myIdentity &&
                 s.verb == ContentVerb.rate
        );
      } catch (_) {
        priorStatement = null;
      }
    }

    like = ValueNotifier(priorStatement?.like);
    dis = ValueNotifier(priorStatement?.dismiss ?? false);
    censor = ValueNotifier(priorStatement?.censor ?? false);
    erase = ValueNotifier(false);
    okEnabled = ValueNotifier(false);
    interpret = ValueNotifier(true);
    commentController = TextEditingController(text: priorStatement?.comment ?? '');
    
    switch (widget.intent) {
      case RateIntent.like:
        like.value = (like.value == true ? null : true);
        break;
      case RateIntent.dislike:
        like.value = (like.value == false ? null : false);
        break;
      case RateIntent.dismiss:
        dis.value = !dis.value;
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
    interpret.dispose();
    super.dispose();
  }

  void listener() {
    okEnabled.value = !compareToPrior || censor.value;
    if (bAllFieldsClear && b(priorStatement)) {
      erase.value = true;
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
      dis.value = b(priorStatement!.dismiss);
      censor.value = b(priorStatement!.censor);
      commentController.text = priorStatement!.comment ?? '';
    }
  }

  bool get compareToPrior {
    if (b(priorStatement)) {
      return like.value == priorStatement!.like &&
          dis.value == b(priorStatement!.dismiss) &&
          censor.value == b(priorStatement!.censor) &&
          commentController.text == (priorStatement!.comment ?? '');
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
      dismiss: trueOrNull(dis.value),
      censor: trueOrNull(censor.value),
      comment: comment,
    );
    Navigator.pop(context, json);
  }

  @override
  Widget build(BuildContext context) {
    final rawSubject = widget.aggregation.subject;
    final isMap = rawSubject is Map;
    final isStatement = isMap && rawSubject.containsKey('statement');

    bool subjectIsMyStatement = false;
    if (isStatement) {
      final String subjectDelegate = Statement.make(Jsonish(Map<String, dynamic>.from(rawSubject))).iToken;
      final String? myIdentity = signInState.identity;
      if (myIdentity != null) {
        subjectIsMyStatement = (myIdentity == widget.model.labeler.getIdentityForToken(subjectDelegate));
      }
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
        key2colors: const {true: Colors.green, false: Colors.red},
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
      censorTooltip = 'The subject here is your own statement. Clear your rating on its parent instead.';
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
        tooltipText: 'Clear (erase) my rating',
        disabled: !b(priorStatement),
        callback: eraseListener);

    return AlertDialog(
      title: const Text('Rate & Comment'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  labelText: 'Subject',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0))),
                child: SizedBox(
                  height: 150,
                  child: JsonDisplay(
                    isMap ? rawSubject : {'token': rawSubject},
                    interpret: interpret, 
                    strikethrough: censor.value
                  )
                )
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [likeButton, disButton, censorButton, eraseButton],
              ),
              const SizedBox(height: 16),
              TextField(
                enabled: editingEnabled,
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...\n#hashtag',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                autofocus: widget.intent == RateIntent.comment,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isStatement)
          SizedBox(
            width: 120.0,
            child: Tooltip(
                message: 'A user can have only one disposition on a subject, so any newer rating will overwrite his earlier one.',
                child: Text('rating a rating?', style: linkStyle)),
          )
        else
          const SizedBox(width: 120.0),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: okEnabled,
          builder: (context, enabled, _) => ElevatedButton(
            onPressed: enabled ? _onOk : null,
            child: const Text('Post'),
          ),
        ),
      ],
    );
  }
}
