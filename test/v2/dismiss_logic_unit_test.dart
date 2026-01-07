import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/content/content_types.dart';
import '../test_utils.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';

void main() {
  ContentStatement.init();
  group('Dismiss Logic', () {
    // Shared test data
    final iJson = {'token': 'test_identity', 'handle': 'tester'};
    final testSubject = createTestSubject();

    test('SubjectAggregation.isDismissed logic', () {
      final t0 = DateTime(2025, 1, 1);
      final t1 = DateTime(2025, 1, 2);

      // Case 1: Not dismissed (no dismissal statement)
      var agg = SubjectAggregation(
        subject: testSubject,
        lastActivity: t1,
        povStatements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
          )..['time'] = t0.toIso8601String())), // Just a rating
        ],
        statements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
          )..['time'] = t1.toIso8601String())), // New activity
        ],
      );
      expect(agg.isDismissed, false);

      // Case 2: Dismissed Forever
      agg = SubjectAggregation(
        subject: testSubject,
        lastActivity: t1,
        povStatements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
            dismiss: 'forever',
          )..['time'] = t0.toIso8601String())),
        ],
        statements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
          )..['time'] = t1.toIso8601String())), // New activity
        ],
      );
      expect(agg.isDismissed, true);

      // Case 3: Snoozed, no new activity
      agg = SubjectAggregation(
        subject: testSubject,
        lastActivity: t0,
        povStatements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
            dismiss: 'snooze',
          )..['time'] = t0.toIso8601String())),
        ],
        statements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
            dismiss: 'snooze',
          )..['time'] = t0.toIso8601String())),
        ],
      );
      expect(agg.isDismissed, true);

      // Case 4: Snoozed, Qualified Activity (Comment)
      agg = SubjectAggregation(
        subject: testSubject,
        lastActivity: t1,
        povStatements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
            dismiss: 'snooze',
          )..['time'] = t0.toIso8601String())),
        ],
        statements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
            comment: 'Hello',
          )..['time'] = t1.toIso8601String())),
        ],
      );
      expect(agg.isDismissed, false);

      // Case 5: Snoozed, Disqualified Activity (Censor)
      agg = SubjectAggregation(
        subject: testSubject,
        lastActivity: t1,
        povStatements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
            dismiss: 'snooze',
          )..['time'] = t0.toIso8601String())),
        ],
        statements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
            censor: true,
          )..['time'] = t1.toIso8601String())),
        ],
      );
      expect(agg.isDismissed, true);

      // Case 6: Snoozed, Qualified Activity (Relate)
      agg = SubjectAggregation(
        subject: testSubject,
        lastActivity: t1,
        povStatements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
            dismiss: 'snooze',
          )..['time'] = t0.toIso8601String())),
        ],
        statements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.relate,
            testSubject,
          )..['time'] = t1.toIso8601String())),
        ],
      );
      expect(agg.isDismissed, false);
      // Case 6: User Dismissal (myDelegateStatements)
      agg = SubjectAggregation(
        subject: testSubject,
        lastActivity: t1,
        myDelegateStatements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
            dismiss: 'forever',
          )..['time'] = t0.toIso8601String())),
        ],
        statements: [
          ContentStatement(Jsonish(ContentStatement.make(
            iJson,
            ContentVerb.rate,
            testSubject,
          )..['time'] = t1.toIso8601String())),
        ],
      );
      expect(agg.isUserDismissed, true);
      expect(agg.isDismissed, false); // POV not dismissed
    });
  });
}
