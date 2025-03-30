import 'package:cloud_functions/cloud_functions.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';

/// TEST
/// TEMP: revoke
/// TEMP: Use: GreedyBfsTrust, maybe others.

class FetcherBatcherResult {
  final List<Json> statements;
  final Json? i;

  FetcherBatcherResult(this.statements, this.i);
}

// Use once
class FetcherBatcher {
  final Json paramsProto;
  final Iterable<String> tokens;
  final Iterable<String?> revokeds;
  final FirebaseFunctions? functions;
  final Map<String, FetcherBatcherResult> fetched = {};

  FetcherBatcher(this.tokens, this.revokeds, this.paramsProto, {this.functions});

  FetcherBatcherResult? get(String token) => fetched[token];

  Future<void> fetch() async {
    if (!b(functions)) return;

    Json params = Map.of(paramsProto);
    params["tokens"] = List.of(tokens);
    // NEXT: params["tokenRevokeds"] = tokenRevokeds;

    final results = await Fetcher.mFire.mAsync(() {
      return functions!.httpsCallable('mclouddistinct').call(params);
    });

    for (Json rd in results.data) {
      // TODO: Weave tokens from tokenRevokeds and results
      List statements = rd["statements"];
      Json? i = rd['I'];
      // BUG: Dave Alexander has no nerdster statements, and so the other code can't tell that he's been fetched.
      if (b(i)) {
        String token = getToken(i);
        fetched[token] = FetcherBatcherResult(statements.cast(), i);
      }
    }
  }
}
