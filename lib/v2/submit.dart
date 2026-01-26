import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/content/dialogs/establish_subject_dialog.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/rate_dialog.dart';

Future<void> v2Submit(BuildContext context, V2FeedController controller) async {
  final model = controller.value;
  if (model == null) return;
  
  if (!bb(await checkSignedIn(context, trustGraph: model.trustGraph))) return;

  Jsonish? subject = await establishSubjectDialog(context);
  if (subject != null) {
    final canonicalToken = ContentKey(subject.token);
    final group = SubjectGroup(
      canonical: canonicalToken,
      lastActivity: DateTime.now(),
    );
    final aggregation = model.aggregation.subjects[canonicalToken] ??
        SubjectAggregation(
          subject: subject.json,
          group: group,
          narrowGroup: group,
        );

    if (context.mounted) {
      await V2RateDialog.show(
        context,
        aggregation,
        controller, // Changed
        // onRefresh removed
      );
    }
  }
}
