import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/setting_type.dart';

import '../test_utils.dart';

// The rules:
// Rate: tokenize when statement, dismiss, censor (comment doesn't matter)
// All relations [relate, equate, dontRelate, dontEquate]: don't tokenize
// Follow: always tokenize (we have the key from the identity network)
// Clear: tokenize

void main() {
  setUpAll(() {
    ContentStatement.init();
  });

  test('ContentStatement.make respects debugUseSubjectNotToken', () async {
    final Json i = {
      "crv": "Ed25519",
      "kty": "OKP",
      "x": "UYB3b66cl4JFkKy3REWI2TvBNc6q2z9-ghrFoneM9eg"
    };

    final Map<String, dynamic> subjectObj = createTestSubject(
      type: ContentType.resource,
      title: 'Test Subject',
      url: 'https://example.com/test',
    );
    final String subjectToken = getToken(subjectObj);

    final Map<String, dynamic> otherObj = createTestSubject(
      type: ContentType.resource,
      title: 'Other Subject',
      url: 'https://example.com/other',
    );
    final String otherToken = getToken(otherObj);

    // Test both settings
    for (bool debugMode in [true, false]) {
      Setting.get(SettingType.debugUseSubjectNotToken).value = debugMode;

      for (ContentVerb verb in [
        ContentVerb.relate,
        ContentVerb.equate,
        ContentVerb.dontRelate,
        ContentVerb.dontEquate
      ]) {
        Json testJson = ContentStatement.make(i, verb, subjectObj, other: otherObj);

        if (debugMode) {
          expect(testJson[verb.label], equals(subjectObj));
        } else {
          expect(testJson[verb.label], equals(subjectObj),
              reason: 'Relations must use full subject');
        }

        ContentStatement testStmt = ContentStatement(Jsonish(testJson));
        expect(getToken(testStmt.subject), equals(subjectToken));
        expect(getToken(testStmt.other), equals(otherToken));
      }

      Json simpleRateJson = ContentStatement.make(i, ContentVerb.rate, subjectObj, recommend: true);
      if (debugMode) {
        expect(simpleRateJson['rate'], equals(subjectObj));
      } else {
        expect(simpleRateJson['rate'], equals(subjectObj));
      }

      Json dismissRateJson = ContentStatement.make(i, ContentVerb.rate, subjectObj, dismiss: true);
      if (debugMode) {
        expect(dismissRateJson['rate'], equals(subjectObj));
      } else {
        expect(dismissRateJson['rate'], equals(subjectObj));
      }

      Json censorRateJson = ContentStatement.make(i, ContentVerb.rate, subjectObj, censor: true);
      if (debugMode) {
        expect(censorRateJson['rate'], equals(subjectObj));
      } else {
        expect(censorRateJson['rate'], equals(subjectToken));
      }

      Json clearJson = ContentStatement.make(i, ContentVerb.clear, subjectObj);
      if (debugMode) {
        expect(clearJson['clear'], equals(subjectObj));
      } else {
        expect(clearJson['clear'], equals(subjectToken));
      }

      Json blockFollowJson =
          ContentStatement.make(i, ContentVerb.follow, subjectObj, contexts: {'all': -1});
      if (debugMode) {
        expect(blockFollowJson['follow'], equals(subjectObj));
      } else {
        expect(blockFollowJson['follow'], equals(subjectToken));
      }

      Json simpleFollowJson =
          ContentStatement.make(i, ContentVerb.follow, subjectObj, contexts: {'all': 1});
      if (debugMode) {
        expect(simpleFollowJson['follow'], equals(subjectObj));
      } else {
        expect(simpleFollowJson['follow'], equals(subjectToken));
      }

      // Test Rate on Statements (Rule 1)
      final Map<String, dynamic> statementSubject = {
        'statement': 'org.nerdster',
        'time': '2026-01-01T00:00:00Z',
        'I': i,
        'rate': subjectObj,
      };
      final String statementToken = getToken(statementSubject);
      Json rateStmtJson =
          ContentStatement.make(i, ContentVerb.rate, statementSubject, recommend: true);
      if (debugMode) {
        expect(rateStmtJson['rate'], equals(statementSubject));
      } else {
        expect(rateStmtJson['rate'], equals(statementToken));
      }

      // Test Relations on Statements (Rule 2 - Should NOT tokenize)
      for (ContentVerb verb in [ContentVerb.relate, ContentVerb.equate]) {
        Json relStmtJson = ContentStatement.make(i, verb, statementSubject, other: otherObj);
        if (debugMode) {
          expect(relStmtJson[verb.label], equals(statementSubject));
        } else {
          expect(relStmtJson[verb.label], equals(statementSubject),
              reason: 'Relations must ALWAYS use full subject, even for statements');
        }
      }
    }
  });
}
