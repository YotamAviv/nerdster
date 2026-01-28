import 'package:flutter/material.dart';
import 'package:nerdster/ui/dialogs/check_signed_in.dart';
import 'package:nerdster/ui/dialogs/establish_subject_dialog.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/ui/rate_dialog.dart';

Future<void> v2Submit(BuildContext context, FeedController controller) async {
  final model = controller.value;
  if (model == null) return;

  if ((await checkSignedIn(context, trustGraph: model.trustGraph)) != true) return;

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
      await RateDialog.show(
        context,
        aggregation,
        controller, // Changed
        // onRefresh removed
      );
    }
  }
}
