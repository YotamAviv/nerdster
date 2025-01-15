import 'package:cloud_functions/cloud_functions.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';

final String yotamNerdster = 'f4e45451dd663b6c9caf90276e366f57e573841b';

/// This Prototyp works, does call the callable cloud function export3.

// Timing seems close. This is with the emulator. Order called affects caching.
// fetch:	 stopwatch.elapsed=0:00:00.078800
// call:	 stopwatch.elapsed=0:00:00.076100
//
// call:	 stopwatch.elapsed=0:00:00.089700
// fetch:	 stopwatch.elapsed=0:00:00.080000
class Getter {
  static Future<void> cloudCall() async {
    try {
      FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);

      final result = await FirebaseFunctions.instance
          .httpsCallable('export3')
          .call({'token': yotamNerdster});
      for (Json x in result.data) {
        ContentStatement s = ContentStatement(Jsonish(x));
        // print(s.subject);
      }
      print(result.data.length);
    } on FirebaseFunctionsException catch (error) {
      print(error.code);
      print(error.details);
      print(error.message);
    }
  }

  static Future<void> fetch() async {
    try {
      Fetcher fetcher = Fetcher(yotamNerdster, kNerdsterDomain);
      await fetcher.fetch();
      print(fetcher.statements.length);
    } on FirebaseFunctionsException catch (error) {
      print(error.code);
      print(error.details);
      print(error.message);
    }
  }


  // Worked
  static Future<void> getGreeting() async {
    try {
      FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);

      final result = await FirebaseFunctions.instance.httpsCallable('getGreeting').call();
      print(result.data as String);
    } on FirebaseFunctionsException catch (error) {
      print(error.code);
      print(error.details);
      print(error.message);
    }
  }
}
