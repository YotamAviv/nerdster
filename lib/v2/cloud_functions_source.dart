import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/v2/io.dart';

/// Fetches statements using the Cloud Function HTTP endpoint.
/// This is the preferred method for Production and Emulator environments as it is more efficient.
///
/// It requests the cloud to:
/// 1. Filter statements up to `revokeAt` if applicable.
/// 2. Apply `distinct` logic (collapse redundant statements).
/// 3. Omit redundant fields (`statement`, `I`) to save bandwidth.
///
/// This class reconstructs the omitted fields on the client side before parsing.
class CloudFunctionsSource<T extends Statement> implements StatementSource<T> {
  final String baseUrl;
  final String statementType;
  final http.Client client;
  final StatementVerifier verifier;
  final Map<String, dynamic>? paramsOverride;

  static const Map<String, dynamic> _paramsProto = {
    "distinct": "true",
    "orderStatements": "false",
    "includeId": "true",
    "checkPrevious": "true",
    // "omit": ['statement', 'I', 'signature', 'previous'], // EXPERIMENTAL
    "omit": ['statement', 'I'],
  };

  CloudFunctionsSource({
    required this.baseUrl,
    http.Client? client,
    required this.verifier,
    this.paramsOverride,
  })  : statementType = Statement.type<T>(),
        client = client ?? http.Client();

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    if (keys.isEmpty) return {};

    final List<dynamic> spec = keys.entries.map((e) {
      if (e.value == null) return e.key;
      return {e.key: e.value};
    }).toList();

    final Map<String, dynamic> params = Map.of(_paramsProto);
    if (paramsOverride != null) {
      params.addAll(paramsOverride!);
    }
    params['spec'] = jsonEncode(spec);

    final Uri uri = Uri.parse(baseUrl).replace(queryParameters: params);

    final http.Request request = http.Request('GET', uri);
    final http.StreamedResponse response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch statements from $baseUrl: ${response.statusCode}');
    }

    final Map<String, List<T>> results = {};
    final bool skipVerify = Setting.get<bool>(SettingType.skipVerify).value;

    await for (final String line
        in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;

      final Map<String, dynamic> jsonToken2Statements = jsonDecode(line);

      for (final MapEntry<String, dynamic> entry in jsonToken2Statements.entries) {
        final String token = entry.key;
        final List<dynamic> statementsJson = entry.value;

        final List<T> list = results.putIfAbsent(token, () => []);

        final Map<String, String> iJson = {'I': token};

        for (final dynamic json in statementsJson) {
          if (!json.containsKey('I')) {
            final Jsonish? cached = Jsonish.find(token);
            if (cached != null) {
              json['I'] = cached.json;
            } else {
              json['I'] = iJson;
            }
          }
          if (!json.containsKey('statement')) json['statement'] = statementType;

          final String? serverToken = json['id'];
          if (serverToken != null) json.remove('id');

          Jsonish jsonish;
          if (!skipVerify) {
            jsonish = await Jsonish.makeVerify(json, verifier);
          } else {
            jsonish = Jsonish(json, serverToken);
          }

          final Statement statement = Statement.make(jsonish);
          list.add(statement as T);
        }
      }
    }

    return results;
  }
}

// EXPERIMENTAL: "EXPERIMENTAL" tagged where the code allows us to not compute the tokens
// but just use the stored values, which allows us to not ask for [signature, previous].
// The changes worked, but the performance hardly changed. And with this, we wouldn't have
// [signature, previous] locally, couldn't verify statements, and there'd be more code
// paths. So, no.
//
// String serverToken = j['id'];
// Jsonish jsonish = Jsonish(j, serverToken);
// j.remove('id');
// assert(jsonish.token == serverToken);
//
// static const Json paramsProto = {
//   "includeId": true,
//   "distinct": true,
//   "checkPrevious": true,
//   "omit": ['statement', 'I', 'signature', 'previous']
//   "orderStatements": false,
// };
