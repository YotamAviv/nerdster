import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/content/content_types.dart';
import '../test_utils.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/keys.dart';

void main() {
  setUpAll(() {
    setUpTestRegistry();
  });

  group('Dismiss Logic', () {
    // Helper to create a dummy statement
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

    test('SubjectAggregation.isDismissed logic', () {
      final DateTime t0 = DateTime(2025, 1, 1);
      final DateTime t1 = DateTime(2025, 1, 2);

      // Case 1: Not dismissed (no dismissal statement)
      final Map<String, dynamic> s1 = createTestSubject();
      final ContentKey c1 = ContentKey(getToken(s1));
      final SubjectGroup group1 = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        povStatements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, time: t0), // Just a rating
        ],
        statements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, time: t1), // New activity
        ],
      );
      SubjectAggregation agg = SubjectAggregation(
        subject: s1,
        group: group1,
        narrowGroup: group1,
      );
      expect(agg.isDismissed, false);

      // Case 2: Dismissed Forever
      final SubjectGroup group2 = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        povStatements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, dismiss: 'forever', time: t0),
        ],
        statements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, time: t1), // New activity
        ],
      );
      agg = SubjectAggregation(
        subject: s1,
        group: group2,
        narrowGroup: group2,
      );
      expect(agg.isDismissed, true);

      // Case 3: Snoozed, no new activity
      final SubjectGroup group3 = SubjectGroup(
        canonical: c1,
        lastActivity: t0,
        povStatements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, dismiss: 'snooze', time: t0),
        ],
        statements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, dismiss: 'snooze', time: t0),
        ],
      );
      agg = SubjectAggregation(
        subject: s1,
        group: group3,
        narrowGroup: group3,
      );
      expect(agg.isDismissed, true);

      // Case 4: Snoozed, Qualified Activity (Comment)
      final SubjectGroup group4 = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        povStatements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, dismiss: 'snooze', time: t0),
        ],
        statements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, comment: 'Hello', time: t1),
        ],
      );
      agg = SubjectAggregation(
        subject: s1,
        group: group4,
        narrowGroup: group4,
      );
      expect(agg.isDismissed, false);

      // Case 5: Snoozed, Disqualified Activity (Censor)
      final SubjectGroup group5 = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        povStatements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, dismiss: 'snooze', time: t0),
        ],
        statements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, censor: true, time: t1),
        ],
      );
      agg = SubjectAggregation(
        subject: s1,
        group: group5,
        narrowGroup: group5,
      );
      expect(agg.isDismissed, true);

      // Case 6: Snoozed, Qualified Activity (Relate)
      final SubjectGroup group6 = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        povStatements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, dismiss: 'snooze', time: t0),
        ],
        statements: <ContentStatement>[
          makeStatement(verb: ContentVerb.relate, subject: c1.value, time: t1),
        ],
      );
      agg = SubjectAggregation(
        subject: s1,
        group: group6,
        narrowGroup: group6,
      );
      expect(agg.isDismissed, false);

      // Case 7: User Dismissal (static method check)
      final List<ContentStatement> myDisses = <ContentStatement>[
        makeStatement(verb: ContentVerb.rate, subject: c1.value, dismiss: 'forever', time: t0),
      ];
      final SubjectGroup group7 = SubjectGroup(
        canonical: c1,
        lastActivity: t1,
        statements: <ContentStatement>[
          makeStatement(verb: ContentVerb.rate, subject: c1.value, time: t1),
        ],
      );
      agg = SubjectAggregation(
        subject: s1,
        group: group7,
        narrowGroup: group7,
      );
      expect(SubjectGroup.checkIsDismissed(myDisses, agg), true);
      expect(agg.isDismissed, false); // POV not dismissed
    });
  });
}
