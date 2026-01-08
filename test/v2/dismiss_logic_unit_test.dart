import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/content/content_types.dart';
import '../test_utils.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';

void main() {
  group('Dismiss Logic', () {
    // Helper to create a dummy statement
    ContentStatement makeStatement({
      required String verb, // TODO: ContentVerb verb,
      String? dismiss,
      String? comment,
      bool? recommend,
      bool? censor,
      DateTime? time,
    }) {
      final json = {
        'statement': 'org.nerdster',
        'time': (time ?? DateTime.now()).toIso8601String(),
        'I': {'k': 'key', 'a': 'algo'}, // Dummy key
        verb: 'subject_token', // TODO: use actual subject structure
      };
      if (comment != null) json['comment'] = comment;
      
      final withx = <String, dynamic>{};
      if (dismiss != null) withx['dismiss'] = dismiss;
      if (recommend != null) withx['recommend'] = recommend;
      if (censor != null) withx['censor'] = censor;
      
      if (withx.isNotEmpty) json['with'] = withx;

      return ContentStatement(Jsonish(json));
    }

    test('SubjectAggregation.isDismissed logic', () {
      final t0 = DateTime(2025, 1, 1);
      final t1 = DateTime(2025, 1, 2);

      // Case 1: Not dismissed (no dismissal statement)
      var agg = SubjectAggregation(
        subject: createTestSubject(),
        lastActivity: t1,
        povStatements: [
          makeStatement(verb: 'rate', time: t0), // Just a rating
        ],
        statements: [
          makeStatement(verb: 'rate', time: t1), // New activity
        ],
      );
      expect(agg.isDismissed, false);

      // Case 2: Dismissed Forever
      agg = SubjectAggregation(
        subject: createTestSubject(),
        lastActivity: t1,
        povStatements: [
          makeStatement(verb: 'rate', dismiss: 'forever', time: t0),
        ],
        statements: [
          makeStatement(verb: 'rate', time: t1), // New activity
        ],
      );
      expect(agg.isDismissed, true);

      // Case 3: Snoozed, no new activity
      agg = SubjectAggregation(
        subject: createTestSubject(),
        lastActivity: t0,
        // TODO: Explain or remove. Why 2 statements at same time?
        povStatements: [
          makeStatement(verb: 'rate', dismiss: 'snooze', time: t0),
        ],
        statements: [
          makeStatement(verb: 'rate', dismiss: 'snooze', time: t0),
        ],
      );
      expect(agg.isDismissed, true);

      // Case 4: Snoozed, Qualified Activity (Comment)
      agg = SubjectAggregation(
        subject: createTestSubject(),
        lastActivity: t1,
        povStatements: [
          makeStatement(verb: 'rate', dismiss: 'snooze', time: t0),
        ],
        statements: [
          makeStatement(verb: 'rate', comment: 'Hello', time: t1),
        ],
      );
      expect(agg.isDismissed, false);

      // Case 5: Snoozed, Disqualified Activity (Censor)
      agg = SubjectAggregation(
        subject: createTestSubject(),
        lastActivity: t1,
        povStatements: [
          makeStatement(verb: 'rate', dismiss: 'snooze', time: t0),
        ],
        statements: [
          makeStatement(verb: 'rate', censor: true, time: t1),
        ],
      );
      expect(agg.isDismissed, true);
      
      // Case 6: Snoozed, Qualified Activity (Relate)
      agg = SubjectAggregation(
        subject: createTestSubject(),
        lastActivity: t1,
        povStatements: [
          makeStatement(verb: 'rate', dismiss: 'snooze', time: t0),
        ],
        statements: [
          makeStatement(verb: 'relate', time: t1),
        ],
      );
      expect(agg.isDismissed, false);
      // Case 6: User Dismissal (myDelegateStatements)
      agg = SubjectAggregation(
        subject: createTestSubject(),
        lastActivity: t1,
        myDelegateStatements: [
          makeStatement(verb: 'rate', dismiss: 'forever', time: t0),
        ],
        statements: [
          makeStatement(verb: 'rate', time: t1),
        ],
      );
      expect(agg.isUserDismissed, true);
      expect(agg.isDismissed, false); // POV not dismissed
    });
  });
}
