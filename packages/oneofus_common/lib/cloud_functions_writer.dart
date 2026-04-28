import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';

class CloudFunctionsWriter<T extends Statement> implements StatementWriter<T> {
  final String baseUrl;
  final String streamId;

  final Map<String, Future<void>> _writeQueues = {};

  CloudFunctionsWriter(this.baseUrl, this.streamId);

  @override
  Future<T> push(Json json, StatementSigner signer,
      {ExpectedPrevious? previous, VoidCallback? optimisticConcurrencyFailed}) async {
    assert(!json.containsKey('previous'), 'unexpected');

    final String issuerToken = getToken(json['I']);

    if (optimisticConcurrencyFailed != null) {
      // Optimistic path: sign immediately with caller-supplied previous, queue the CF call.
      if (previous != null && previous.token != null) {
        json['previous'] = previous.token!;
      }
      final jsonish = await Jsonish.makeSign(json, signer);
      final Future<void> prev = _writeQueues[issuerToken] ?? Future.value();
      _writeQueues[issuerToken] = prev.catchError((_) {}).then((_) async {
        try {
          await _callCF(jsonish);
        } catch (_) {
          optimisticConcurrencyFailed();
        }
      });
      return Statement.make(jsonish) as T;
    }

    // Serialized path: sign and send inside the queue so 'previous' is always accurate.
    // On a previous-mismatch the server returns the correct head token; retry once with it.
    final completer = Completer<T>();
    final Future<void> prev = _writeQueues[issuerToken] ?? Future.value();
    _writeQueues[issuerToken] = prev.catchError((_) {}).then((_) async {
      try {
        final Json j = Map.from(json);
        if (previous?.token != null) j['previous'] = previous!.token!;
        final Jsonish jsonish = await Jsonish.makeSign(j, signer);
        await _callCF(jsonish);
        completer.complete(Statement.make(jsonish) as T);
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });
    return completer.future;
  }

  Future<void> _callCF(Jsonish jsonish) async {
    final response = await http.post(
      Uri.parse('$baseUrl/write'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': {'statement': jsonish.json, 'collection': streamId}}),
    );
    if (response.statusCode != 200) {
      debugPrint('CloudFunctionsWriter._callCF: ${response.statusCode} ${response.body}');
      throw Exception('write failed: ${response.statusCode} ${response.body}');
    }
  }
}
