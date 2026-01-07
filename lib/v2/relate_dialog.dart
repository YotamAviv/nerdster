import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/oneofus/util.dart';

class V2RelateDialog extends StatefulWidget {
  final SubjectAggregation subject1;
  final SubjectAggregation subject2;
  final V2FeedModel model;

  const V2RelateDialog({
    super.key,
    required this.subject1,
    required this.subject2,
    required this.model,
  });

  static Future<void> show(
    BuildContext context,
    SubjectAggregation subject1,
    SubjectAggregation subject2,
    V2FeedModel model, {
    VoidCallback? onRefresh,
  }) async {
    if (!bb(await checkSignedIn(context, trustGraph: model.trustGraph))) return;

    final result = await showDialog<Json>(
      context: context,
      builder: (context) => V2RelateDialog(
        subject1: subject1,
        subject2: subject2,
        model: model,
      ),
    );

    if (result != null) {
      try {
        final writer = SourceFactory.getWriter(kNerdsterDomain, context: context, labeler: model.labeler);
        await writer.push(result, signInState.signer!);
        onRefresh?.call();
      } catch (e, stackTrace) {
        if (e.toString().contains('LGTM check failed')) return;
        debugPrint('V2RelateDialog Error: $e\n$stackTrace');
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
  State<V2RelateDialog> createState() => _V2RelateDialogState();
}

class _V2RelateDialogState extends State<V2RelateDialog> {
  ContentVerb _verb = ContentVerb.relate;
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final title1 = _getTitle(widget.subject1);
    final title2 = _getTitle(widget.subject2);

    return AlertDialog(
      title: const Text('Relate Subjects'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject 1: $title1', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Subject 2: $title2', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            const Text('Relationship:'),
            RadioListTile<ContentVerb>(
              title: const Text('Relate (Related to)'),
              value: ContentVerb.relate,
              groupValue: _verb,
              onChanged: (val) => setState(() => _verb = val!),
            ),
            RadioListTile<ContentVerb>(
              title: const Text('Un-Relate (Not related to)'),
              value: ContentVerb.dontRelate,
              groupValue: _verb,
              onChanged: (val) => setState(() => _verb = val!),
            ),
            RadioListTile<ContentVerb>(
              title: const Text('Equate (Same as)'),
              value: ContentVerb.equate,
              groupValue: _verb,
              onChanged: (val) => setState(() => _verb = val!),
            ),
            RadioListTile<ContentVerb>(
              title: const Text('Un-Equate (Not same as)'),
              value: ContentVerb.dontEquate,
              groupValue: _verb,
              onChanged: (val) => setState(() => _verb = val!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comment (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  String _getTitle(SubjectAggregation agg) {
    final subject = agg.subject;
    return subject['title'] ?? 'Untitled';
  }

  Future<void> _submit() async {
    final json = ContentStatement.make(
      signInState.delegatePublicKeyJson!,
      _verb,
      widget.subject1.subject,
      other: widget.subject2.subject,
      comment: _commentController.text.isNotEmpty ? _commentController.text : null,
    );
    if (mounted) {
      Navigator.pop(context, json);
    }
  }
}
