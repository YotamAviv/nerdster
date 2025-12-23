import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/v2/io.dart';

/// Fetches statements using the Cloud Function HTTP endpoint.
/// This is the preferred method for Production and Emulator environments as it is more efficient.
///
/// It requests the cloud to:
/// 1. Filter by `revokeAt` (time travel).
/// 2. Apply `distinct` logic (collapse redundant statements).
/// 3. Omit redundant fields (`statement`, `I`) to save bandwidth.
///
/// This class reconstructs the omitted fields on the client side before parsing.
class CloudFunctionsSource<T extends Statement> implements StatementSource<T> {
  final String baseUrl;
  final String statementType;
  final http.Client client;
  final List<String>? omit;

  CloudFunctionsSource({
    required this.baseUrl,
    required this.statementType,
    http.Client? client,
    this.omit = const ['statement', 'I'],
  }) : client = client ?? http.Client();

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    if (keys.isEmpty) return {};

    final spec = keys.entries.map((e) {
      if (e.value == null) return e.key;
      return {e.key: e.value};
    }).toList();

    final Map<String, dynamic> params = {
      'distinct': 'true',
      'orderStatements': 'false',
      'includeId': 'true',
      'spec': jsonEncode(spec),
    };
    if (omit != null) {
      params['omit'] = omit;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    
    final request = http.Request('GET', uri);
    final response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch statements from $baseUrl: ${response.statusCode}');
    }

    final Map<String, List<T>> results = {};

    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      print('CloudFunctionsSource received line length: ${line.length}');
      if (line.length < 500) print('CloudFunctionsSource received line: $line');
      
      final Map<String, dynamic> jsonToken2Statements = jsonDecode(line);
      
      for (var entry in jsonToken2Statements.entries) {
        final token = entry.key;
        final List statementsJson = entry.value;
        
        final list = results.putIfAbsent(token, () => []);
        
        final iJson = {'I': token};

        for (var json in statementsJson) {
          if (!json.containsKey('I')) {
            final cached = Jsonish.find(token);
            if (cached != null) {
              json['I'] = cached.json;
            } else {
              json['I'] = iJson;
            }
          }
          if (!json.containsKey('statement')) json['statement'] = statementType;
          
          String? serverToken = json['id'];
          if (serverToken != null) json.remove('id');

          final jsonish = Jsonish(json, serverToken);
          list.add(Statement.make(jsonish) as T);
        }
      }
    }
    
    return results;
  }
}
