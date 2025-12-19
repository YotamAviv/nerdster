import 'dart:convert';
import 'dart:io';
import 'package:nerdster/v2/io.dart';
import 'package:test/test.dart';

void main() {
  group('V2 IO', () {
    test('Parses Lisa sample data', () async {
      final file = File('test/v2/lisa_oneofus.json');
      if (!await file.exists()) {
        // Skip if user hasn't run the fetch script yet
        print('Skipping test: test/v2/lisa_oneofus.json not found.');
        return;
      }

      final jsonString = await file.readAsString();
      final Map<String, dynamic> rawData = jsonDecode(jsonString);
      
      // The key in the sample file is the root token
      final rootKey = rawData.keys.first;
      
      final source = MemorySource(rawData.cast<String, List<dynamic>>());
      final atoms = await source.fetch([rootKey]);

      expect(atoms, isNotEmpty);
      
      // Verify the first atom (should be the newest one)
      final first = atoms.first;
      print('Parsed Statement: $first');
      
      expect(first.issuer, isNotNull);
      expect(first.subject, isNotNull);
      expect(first.verb, isNotNull);
      expect(first.time, isNotNull);
      
      // Check for specific known values from the sample if possible
      // e.g. Lisa's key
      expect(first.issuer, equals(rootKey)); 
    });
  });
}
