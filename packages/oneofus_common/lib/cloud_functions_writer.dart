import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_writer.dart';

class CloudFunctionsWriter<T extends Statement> implements StatementWriter<T> {
  final FirebaseFunctions _functions;
  final String streamId;

  CloudFunctionsWriter(this._functions, this.streamId);

  @override
  Future<T> push(Json json, StatementSigner signer,
      {ExpectedPrevious? previous, VoidCallback? optimisticConcurrencyFailed}) async {
    assert(!json.containsKey('previous'), 'unexpected');
    if (previous != null && previous.token != null) {
      json['previous'] = previous.token!;
    }
    final jsonish = await Jsonish.makeSign(json, signer);
    await _functions.httpsCallable('writeStatement').call({
      'statement': jsonish.json,
      'collection': streamId,
    });
    return Statement.make(jsonish) as T;
  }
}
