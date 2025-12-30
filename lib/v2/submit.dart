import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/content/dialogs/establish_subject_dialog.dart';
import 'package:nerdster/v2/rate_dialog.dart';
import 'package:nerdster/v2/model.dart';

Future<void> v2Submit(BuildContext context, V2FeedModel model, {VoidCallback? onRefresh}) async {
  Jsonish? subject = await establishSubjectDialog(context);
  if (subject != null) {
    final canonicalToken = subject.token;
    final aggregation = model.aggregation.subjects[canonicalToken] ?? 
        SubjectAggregation(
          canonicalToken: canonicalToken,
          subject: subject.json,
          lastActivity: DateTime.now(),
        );
        
    if (context.mounted) {
      await V2RateDialog.show(
        context,
        aggregation,
        model,
        onRefresh: onRefresh,
      );
    }
  }
}
