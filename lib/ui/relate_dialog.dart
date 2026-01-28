import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/ui/subject_view.dart';

class RelateDialog extends StatefulWidget {
  final SubjectAggregation subject1;
  final SubjectAggregation subject2;
  final FeedModel model;

  const RelateDialog({
    super.key,
    required this.subject1,
    required this.subject2,
    required this.model,
  });

  static Future<ContentStatement?> show(
    BuildContext context,
    SubjectAggregation subject1,
    SubjectAggregation subject2,
    FeedController controller, {
    VoidCallback? onRefresh,
  }) async {
    final model = controller.value;
    if (model == null) return null;
    if ((await checkSignedIn(context, trustGraph: model.trustGraph)) != true) return null;

    final result = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RelateDialog(
        subject1: subject1,
        subject2: subject2,
        model: model,
      ),
    );

    if (result != null) {
      return (await controller.push(result, signInState.signer!, context: context))
          as ContentStatement?;
    }
    return null;
  }

  @override
  State<RelateDialog> createState() => _RelateDialogState();
}

class _RelateDialogState extends State<RelateDialog> {
  ContentVerb _verb = ContentVerb.relate;
  final TextEditingController _commentController = TextEditingController();
  late SubjectAggregation _subject1;
  late SubjectAggregation _subject2;
  bool _hasPrior = false;

  @override
  void initState() {
    super.initState();
    _subject1 = widget.subject1;
    _subject2 = widget.subject2;
    _initFromHistory();
  }

  void _initFromHistory() {
    // Use the latest statement about either subject literal token that involves both tokens.
    final t1 = _subject1.token;
    final t2 = _subject2.token;

    final myLiteralStatements = widget.model.aggregation.myLiteralStatements;
    final s1 = List<ContentStatement>.from(myLiteralStatements[t1] ?? []);
    final s2 = List<ContentStatement>.from(myLiteralStatements[t2] ?? []);

    final all = [...s1, ...s2];
    all.sort((a, b) => b.time.compareTo(a.time));

    final prior = all.where((s) {
      final tokens = s.involvedTokens.toSet();
      return tokens.contains(t1.value) && tokens.contains(t2.value);
    }).firstOrNull;

    if (prior != null) {
      // Re-order to match history if needed
      if (prior.subjectToken == t2.value) {
        final tmp = _subject1;
        _subject1 = _subject2;
        _subject2 = tmp;
      }
      _hasPrior = prior.verb != ContentVerb.clear;
      _verb = (prior.verb == ContentVerb.clear) ? ContentVerb.relate : prior.verb;
      _commentController.text = prior.comment ?? '';
    } else {
      _hasPrior = false;
      _verb = ContentVerb.relate;
      _commentController.text = '';
    }
  }

  void _flip() {
    setState(() {
      final tmp = _subject1;
      _subject1 = _subject2;
      _subject2 = tmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isEquate = _verb == ContentVerb.equate;
    final String label1 = isEquate ? 'Canonical' : 'Subject 1';
    final String label2 = isEquate ? 'Equivalent' : 'Subject 2';
    final String title = switch (_verb) {
      ContentVerb.relate => 'Relate Subjects',
      ContentVerb.dontRelate => 'Un-Relate Subjects',
      ContentVerb.equate => 'Equate Subjects',
      ContentVerb.dontEquate => 'Un-Equate Subjects',
      ContentVerb.clear => 'Clear Relationship',
      _ => 'Relate Subjects',
    };

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
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                      labelText: label1,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0)),
                    ),
                    child: SubjectView(
                      subject: _subject1.subject,
                      labeler: widget.model.labeler,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Opacity(
                          opacity: isEquate ? 1.0 : 0.0,
                          child: IgnorePointer(
                            ignoring: !isEquate,
                            child: IconButton(
                              icon: const Icon(Icons.swap_vert),
                              onPressed: _flip,
                              tooltip: 'Swap subjects',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<ContentVerb>(
                            value: _verb,
                            style: const TextStyle(fontSize: 16, color: Colors.black),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: ContentVerb.relate,
                                child: Text('is related to', style: TextStyle(fontSize: 16)),
                              ),
                              const DropdownMenuItem(
                                value: ContentVerb.dontRelate,
                                child: Text('is not related to', style: TextStyle(fontSize: 16)),
                              ),
                              const DropdownMenuItem(
                                value: ContentVerb.equate,
                                child: Text('is the same as', style: TextStyle(fontSize: 16)),
                              ),
                              const DropdownMenuItem(
                                value: ContentVerb.dontEquate,
                                child: Text('is not the same as', style: TextStyle(fontSize: 16)),
                              ),
                              DropdownMenuItem(
                                value: ContentVerb.clear,
                                enabled: _hasPrior,
                                child: const Text('Clear', style: TextStyle(fontSize: 16)),
                              ),
                            ],
                            onChanged: (val) => setState(() => _verb = val!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Visibility(
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          visible: false,
                          child: IconButton(
                            icon: Icon(Icons.swap_vert),
                            onPressed: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InputDecorator(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                      labelText: label2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0)),
                    ),
                    child: SubjectView(
                      subject: _subject2.subject,
                      labeler: widget.model.labeler,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: 'Comment (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Publish'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final json = ContentStatement.make(
      signInState.delegatePublicKeyJson!,
      _verb,
      _subject1.subject,
      other: _subject2.subject,
      comment: _commentController.text.isNotEmpty ? _commentController.text : null,
    );
    if (mounted) {
      Navigator.pop(context, json);
    }
  }
}
