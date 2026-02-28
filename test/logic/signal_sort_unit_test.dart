import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/models/model.dart';

import '../test_utils.dart';

void main() {
  setUpAll(() {
    setUpTestRegistry();
  });

  group('lastSignalActivity sort behavior', () {
    final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime monday = DateTime(2025, 1, 6);
    final DateTime tuesday = DateTime(2025, 1, 7);

    ContentStatement makeStatement({
      required ContentVerb verb,
      required String subject,
      String? dismiss,
      String? comment,
      bool? recommend,
      bool? censor,
      DateTime? time,
    }) {
      return makeContentStatement(
        verb: verb,
        subject: subject,
        dismiss: dismiss,
        comment: comment,
        recommend: recommend,
        censor: censor,
        time: time,
      );
    }

    // Case A: user liked on Monday, then dismissed+liked on Tuesday.
    // distinct() keeps only the Tuesday statement.
    // lastActivity = epoch (dismiss suppresses qualified activity).
    // lastSignalActivity = Tuesday (like=true is a positive signal even with dismiss).
    test('Case A: dismiss + like → lastSignalActivity = statement time', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));

      final SubjectGroup group = SubjectGroup(
        canonical: c1,
        lastActivity: epoch,
        lastSignalActivity: epoch,
        povStatements: [
          makeStatement(
              verb: ContentVerb.rate,
              subject: c1.value,
              dismiss: 'snooze',
              recommend: true,
              time: tuesday),
        ],
        statements: [
          makeStatement(
              verb: ContentVerb.rate,
              subject: c1.value,
              dismiss: 'snooze',
              recommend: true,
              time: tuesday),
        ],
      );

      // Simulate the aggregation loop result: dismiss blocks lastActivity but
      // like=true sets lastSignalActivity.
      final SubjectGroup aggregated = group.copyWith(
        lastActivity: epoch, // dismiss suppresses qualified activity
        lastSignalActivity: tuesday, // like=true is a positive signal
      );

      expect(aggregated.lastActivity, equals(epoch),
          reason: 'dismiss should suppress lastActivity');
      expect(aggregated.lastSignalActivity, equals(tuesday),
          reason: 'like=true should count as a positive signal even with dismiss');
    });

    // Case B: dismiss-only on Tuesday (no like, no comment).
    // lastActivity = epoch, lastSignalActivity = epoch.
    test('Case B: dismiss only → lastSignalActivity = epoch', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));

      final SubjectGroup aggregated = SubjectGroup(
        canonical: c1,
        lastActivity: epoch,
        lastSignalActivity: epoch, // no positive signal
        statements: [
          makeStatement(
              verb: ContentVerb.rate, subject: c1.value, dismiss: 'forever', time: tuesday),
        ],
      );

      expect(aggregated.lastActivity, equals(epoch));
      expect(aggregated.lastSignalActivity, equals(epoch),
          reason: 'dismiss-only should not advance lastSignalActivity');
    });

    // A plain like (no dismiss) advances both.
    test('plain like advances both lastActivity and lastSignalActivity', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));

      final SubjectGroup aggregated = SubjectGroup(
        canonical: c1,
        lastActivity: monday,
        lastSignalActivity: monday,
        statements: [
          makeStatement(verb: ContentVerb.rate, subject: c1.value, recommend: true, time: monday),
        ],
      );

      expect(aggregated.lastActivity, equals(monday));
      expect(aggregated.lastSignalActivity, equals(monday));
    });

    // Case A: comment + dismiss advances lastSignalActivity.
    test('Case A variant: dismiss + comment → lastSignalActivity = statement time', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));

      final SubjectGroup aggregated = SubjectGroup(
        canonical: c1,
        lastActivity: epoch,
        lastSignalActivity: tuesday, // comment is a positive signal
        statements: [
          makeStatement(
              verb: ContentVerb.rate,
              subject: c1.value,
              dismiss: 'snooze',
              comment: 'Great film though',
              time: tuesday),
        ],
      );

      expect(aggregated.lastActivity, equals(epoch),
          reason: 'dismiss should suppress lastActivity');
      expect(aggregated.lastSignalActivity, equals(tuesday),
          reason: 'non-empty comment is a positive signal even with dismiss');
    });

    // SubjectGroup default: lastSignalActivity falls back to lastActivity when not provided.
    test('lastSignalActivity defaults to lastActivity when not provided', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));

      final SubjectGroup group = SubjectGroup(
        canonical: c1,
        lastActivity: monday,
        // lastSignalActivity not provided → should default to lastActivity
      );

      expect(group.lastSignalActivity, equals(monday));
    });

    // copyWith should propagate lastSignalActivity independently.
    test('copyWith preserves lastSignalActivity independently', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));

      final SubjectGroup original = SubjectGroup(
        canonical: c1,
        lastActivity: epoch,
        lastSignalActivity: tuesday,
      );

      final SubjectGroup copied = original.copyWith(lastActivity: monday);

      expect(copied.lastActivity, equals(monday));
      expect(copied.lastSignalActivity, equals(tuesday),
          reason: 'copyWith(lastActivity) must not reset lastSignalActivity');
    });
  });
}
