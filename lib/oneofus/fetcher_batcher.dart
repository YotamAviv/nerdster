import 'package:cloud_functions/cloud_functions.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';

/// Plan:
/// 
/// CODE: Figure out how we want to prefetch batches..
/// 
/// CODE: Clean up index.js
/// 
/// TEST:
/// - Integration test (necessary because Cloud Functions)
///   ...
/// 
/// - Implement revoke
///   Considerations: change the Cloud Functions interface from ?token=token to ?i=token or i={token: revokedAt}
///   TEST:
/// 
/// - Remove "I" (and "statement") from results and just return statements
///   I believe that the only reason "I" was needed was when we come at a Nerdster link with oneofus=token, and so change that to oneofus={key}
///   This is a big change as SignInState.signIn takes "String center".
/// 
/// - Clean up the progress/measure business
/// 
/// - Use elsewhere: GreedyBfsTrust, maybe others.

// Use once
class FetcherBatcher {
  final Json paramsProto;
  final Map<String, String?> token2revoked;
  final FirebaseFunctions? functions;
  final Map<String, Json> fetched = {};

  FetcherBatcher(this.token2revoked, this.paramsProto, {this.functions});

  Json? get(String token) => fetched[token];

  Future<void> fetch() async {
    if (!b(functions)) return;

    Json params = Map.of(paramsProto);
    params["token2revoked"] = token2revoked;
    // NEXT: params["tokenRevokeds"] = tokenRevokeds;

    final results = await Fetcher.mFire.mAsync(() async {
      return await functions!.httpsCallable('mclouddistinct').call(params);
    });

    for (Json rd in results.data) {
      // TODO: Weave tokens from tokenRevokeds and results
      List<Json> statements = rd["statements"].cast<Json>();
      Json? i = rd['I'];
      // BUG: Dave Alexander has no nerdster statements, and so the other code can't tell that he's been fetched.
      if (b(i)) {
        String token = getToken(i);
        fetched[token] = {"statements": statements, "I": i};
      }
    }
  }
}
