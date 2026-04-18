import 'package:flutter_test/flutter_test.dart';
import '../test_utils.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';

DismissStatement _makeDis(String subjectToken, String? dismiss, {DateTime? time}) {
  final Json json = DismissStatement.make(mockKey(), subjectToken, dismiss);
  if (time != null) json['time'] = time.toIso8601String();
  return DismissStatement(Jsonish(json));
}

void main() {
  setUpAll(() {
    setUpTestRegistry();
  });

  group('Dismiss Logic', () {
    final DateTime t0 = DateTime(2025, 1, 1);
    final DateTime t1 = DateTime(2025, 1, 2);

    test('Not dismissed: empty dis list → false', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));
      final SubjectGroup group = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        statements: [makeContentStatement(verb: ContentVerb.rate, subject: c1.value, time: t1)],
      );
      final agg = SubjectAggregation(subject: s1, group: group, narrowGroup: group);
      expect(SubjectGroup.checkIsDismissed([], agg), false);
    });

    test('Dismissed forever → true regardless of new activity', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));
      final SubjectGroup group = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        statements: [makeContentStatement(verb: ContentVerb.rate, subject: c1.value, time: t1)],
      );
      final agg = SubjectAggregation(subject: s1, group: group, narrowGroup: group);
      expect(SubjectGroup.checkIsDismissed([_makeDis(c1.value, 'forever', time: t0)], agg), true);
    });

    test('Snoozed at t0, no new activity (lastActivity=t0) → still dismissed', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));
      final SubjectGroup group = SubjectGroup(
        canonical: c1,
        lastActivity: t0,
        statements: [makeContentStatement(verb: ContentVerb.rate, subject: c1.value, time: t0)],
      );
      final agg = SubjectAggregation(subject: s1, group: group, narrowGroup: group);
      expect(SubjectGroup.checkIsDismissed([_makeDis(c1.value, 'snooze', time: t0)], agg), true);
    });

    test('Snoozed at t0, new comment at t1 → woken (not dismissed)', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));
      final SubjectGroup group = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        statements: [
          makeContentStatement(
              verb: ContentVerb.rate, subject: c1.value, comment: 'Hello', time: t1),
        ],
      );
      final agg = SubjectAggregation(subject: s1, group: group, narrowGroup: group);
      expect(SubjectGroup.checkIsDismissed([_makeDis(c1.value, 'snooze', time: t0)], agg), false);
    });

    test('Snoozed at t0, censor activity at t1 → censor does NOT wake snooze', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));
      final SubjectGroup group = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        statements: [
          makeContentStatement(
              verb: ContentVerb.rate, subject: c1.value, censor: true, time: t1),
        ],
      );
      final agg = SubjectAggregation(subject: s1, group: group, narrowGroup: group);
      expect(SubjectGroup.checkIsDismissed([_makeDis(c1.value, 'snooze', time: t0)], agg), true);
    });

    test('Snoozed at t0, relate activity at t1 → woken (not dismissed)', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));
      final Map<String, dynamic> s2 = createTestSubject();
      final SubjectGroup group = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        statements: [
          makeContentStatement(
              verb: ContentVerb.relate, subject: c1.value, other: getToken(s2), time: t1),
        ],
      );
      final agg = SubjectAggregation(subject: s1, group: group, narrowGroup: group);
      expect(SubjectGroup.checkIsDismissed([_makeDis(c1.value, 'snooze', time: t0)], agg), false);
    });

    test('Clear statement (null dismiss) → not dismissed', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));
      final SubjectGroup group = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        statements: [makeContentStatement(verb: ContentVerb.rate, subject: c1.value, time: t1)],
      );
      final agg = SubjectAggregation(subject: s1, group: group, narrowGroup: group);
      // A clear (null dismiss) overrides a prior forever — list is [clear, forever] desc
      expect(
          SubjectGroup.checkIsDismissed([
            _makeDis(c1.value, null, time: t1), // most recent: clear
            _makeDis(c1.value, 'forever', time: t0),
          ], agg),
          false);
    });

    test('Snoozed at t0, new like at t1 → woken (not dismissed)', () {
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));
      final SubjectGroup group = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        statements: [
          makeContentStatement(
              verb: ContentVerb.rate, subject: c1.value, recommend: true, time: t1),
        ],
      );
      final agg = SubjectAggregation(subject: s1, group: group, narrowGroup: group);
      expect(SubjectGroup.checkIsDismissed([_makeDis(c1.value, 'snooze', time: t0)], agg), false);
    });
  });
}
