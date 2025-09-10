import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

// TEMP: This works for me using the emulator
// I haven't deployed the cloud function
// I have the emulator address hard-coded.

class FindNew {
  static make() async {
    List<Statement> out = <Statement>[];

    try {
      // Call the Cloud Function to get collection names
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5002/one-of-us-net/us-central1/listCollections'),
      );

      if (response.statusCode != 200) {
        print('Failed to fetch collections: ${response.statusCode} - ${response.body}');
        return out;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      List<String> collectionNames = List<String>.from(data['collections']!);
      for (String collectionName in collectionNames) {
        Fetcher f = Fetcher(collectionName, kOneofusDomain);
        for (Statement s in await f.fetchAllNoVerify()) {
          TrustStatement ts = s as TrustStatement;

          if (ts.time.isAfter(DateTime.now().subtract(Duration(days: 20)))) {
            print(ts.moniker);
            print(jsonEncode(ts.i));
            print('\n');
          }
        }
      }
    } catch (e) {
      print('Error calling Cloud Function: $e');
      return out;
    }
    print('out');
  }
}
