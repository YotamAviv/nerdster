import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement_source.dart';

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
  final ValueListenable<bool>? skipVerify;
  final Json? paramsOverride;
  final Map<String, SourceError> _errors = {};

  static const Json _paramsProto = {
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
    this.skipVerify,
    this.paramsOverride,
  })  : statementType = Statement.type<T>(),
        client = client ?? http.Client();

  @override
  List<SourceError> get errors => List.unmodifiable(_errors.values);

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    for (final key in keys.keys) _errors.remove(key);
    if (keys.isEmpty) return {};

    final List<dynamic> spec = keys.entries.map((e) {
      if (e.value == null) return e.key;
      return {e.key: e.value};
    }).toList();

    final Json params = Map.of(_paramsProto);
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
    final bool skipCheck = skipVerify?.value ?? false;

    await for (final String line
        in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;

      // Expect: { "abc": [...] } or { "abc": { "error": "..." } }
      final Json jsonToken2Statements = jsonDecode(line);

      for (final MapEntry<String, dynamic> entry in jsonToken2Statements.entries) {
        final String token = entry.key;
        final dynamic value = entry.value;

        if (value is Map && value.containsKey('error')) {
          final String msg = value['error'];
          _errors[token] = SourceError(msg, token: token);
          results.remove(token);
          continue;
        }

        final List<dynamic> statementsJson = value as List<dynamic>;

        final List<T> list = results.putIfAbsent(token, () => []);

        final Map<String, String> iJson = {'I': token};

        try {
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
            if (!skipCheck) {
              try {
                jsonish = await Jsonish.makeVerify(json, verifier);
              } catch (e) {
                throw SourceError(
                  'Invalid Signature: $e',
                  token: token,
                  originalError: e,
                );
              }
            } else {
              jsonish = Jsonish(json, serverToken);
            }

            final Statement statement = Statement.make(jsonish);
            list.add(statement as T);
          }
        } catch (e) {
          if (e is SourceError) {
            _errors[token] = e;
          } else {
            _errors[token] = SourceError(
              'Error processing statements: $e',
              token: token,
              originalError: e,
            );
          }
          results.remove(token);
          continue;
        }
      }
    }

    for (final token in results.keys) {
      results[token] = List.unmodifiable(results[token]!);
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
