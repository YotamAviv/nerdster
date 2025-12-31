import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/setting_type.dart';

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
    
    final Map<String, dynamic> subjectObj = {
      'contentType': 'resource',
      'title': 'Test Subject',
      'url': 'https://example.com/test'
    };
    final String subjectToken = getToken(subjectObj);

    final Map<String, dynamic> otherObj = {
      'contentType': 'resource',
      'title': 'Other Subject',
      'url': 'https://example.com/other'
    };
    final String otherToken = getToken(otherObj);

    // Test both settings
    for (bool debugMode in [true, false]) {
      print('Testing with debugUseSubjectNotToken = $debugMode');
      Setting.get(SettingType.debugUseSubjectNotToken).value = debugMode;

      // 1. Rate
      Json rateJson = ContentStatement.make(
        i,
        ContentVerb.rate,
        subjectObj,
        recommend: true,
      );
      
      // Rate always uses token in the current implementation logic for 'rate' verb?
      // Let's check the logic in ContentStatement.make:
      // if (verb == ContentVerb.rate ...) { ... s = getToken(s); }
      // else { if (!debug) s = getToken(s); }
      
      // Wait, the logic I implemented was:
      // if (verb == rate || verb == clear) {
      //   ... logic to force token if censor/dismiss/statement ...
      // } else {
      //   if (!debug) { s = getToken(s); ... }
      // }
      
      // So 'rate' logic is NOT affected by the debug setting in the 'else' block.
      // It seems 'rate' logic is separate.
      // "This helper encapsulates the logic for creating content statements, including the conditional tokenization for rate/clear and the default tokenization for relate/equate."
      
      // The user asked to "Add a test that exercises some dismiss, censor, relate, dontRelate, equate, dontEquate".
      // Relate/Equate ARE affected.
      
      // 2. Relate
      Json relateJson = ContentStatement.make(
        i,
        ContentVerb.relate,
        subjectObj,
        other: otherObj,
      );

      if (debugMode) {
        // Should contain full objects
        expect(relateJson['relate'], equals(subjectObj), reason: 'Subject should be full object when debug=true');
        expect(relateJson['with']['otherSubject'], equals(otherObj), reason: 'Other should be full object when debug=true');
      } else {
        // Should contain tokens
        expect(relateJson['relate'], equals(subjectToken), reason: 'Subject should be token when debug=false');
        expect(relateJson['with']['otherSubject'], equals(otherToken), reason: 'Other should be token when debug=false');
      }

      // Verify that we can create a ContentStatement from it and it has the same effect (same tokens)
      ContentStatement relateStmt = ContentStatement(Jsonish(relateJson));
      expect(getToken(relateStmt.subject), equals(subjectToken));
      expect(getToken(relateStmt.other), equals(otherToken));


      // 3. Equate
      Json equateJson = ContentStatement.make(
        i,
        ContentVerb.equate,
        subjectObj,
        other: otherObj,
      );

      if (debugMode) {
        expect(equateJson['equate'], equals(subjectObj));
        expect(equateJson['with']['otherSubject'], equals(otherObj));
      } else {
        expect(equateJson['equate'], equals(subjectToken));
        expect(equateJson['with']['otherSubject'], equals(otherToken));
      }
      
      ContentStatement equateStmt = ContentStatement(Jsonish(equateJson));
      expect(getToken(equateStmt.subject), equals(subjectToken));
      expect(getToken(equateStmt.other), equals(otherToken));
      
      // 4. DontRelate
      Json dontRelateJson = ContentStatement.make(
        i,
        ContentVerb.dontRelate,
        subjectObj,
        other: otherObj,
      );
       if (debugMode) {
        expect(dontRelateJson['dontRelate'], equals(subjectObj));
      } else {
        expect(dontRelateJson['dontRelate'], equals(subjectToken));
      }
      ContentStatement dontRelateStmt = ContentStatement(Jsonish(dontRelateJson));
      expect(getToken(dontRelateStmt.subject), equals(subjectToken));


      // 5. Rate (Check that it is NOT affected by debug setting, or at least behaves consistently)
      // The current logic for Rate forces tokenization if (censor || dismiss || isStatement).
      // If just a simple rate, does it use the object?
      // Logic:
      // if (verb == rate ...) {
      //    if (censor || dismiss || isStatement) s = getToken(s);
      // }
      // It does NOT go into the 'else' block where 'debug' is checked.
      // So if it's a simple rate, 's' remains 'subjectObj'.
      // Wait, if it's a simple rate, it falls through the first if block?
      // No, the first if block is `if (verb == rate || verb == clear)`.
      // So for Rate, it enters the block.
      // If `censor`, `dismiss`, or `isStatement` is true, it tokenizes.
      // If NOT, it leaves `s` as is (full object).
      // So `debugUseSubjectNotToken` has NO EFFECT on Rate in the current implementation.
      
      Json simpleRateJson = ContentStatement.make(
        i,
        ContentVerb.rate,
        subjectObj,
        recommend: true,
      );
      // Should be full object regardless of setting?
      expect(simpleRateJson['rate'], equals(subjectObj));
      
      Json dismissRateJson = ContentStatement.make(
        i,
        ContentVerb.rate,
        subjectObj,
        dismiss: true,
      );
      // Should be token because of dismiss logic
      expect(dismissRateJson['rate'], equals(subjectToken));

    }
  });
}
