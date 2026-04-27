// App-specific sign-in wiring for Nerdster. Parallel to hablotengo/lib/sign_in_session.dart.
// Shared session mechanics live in nerdster_common/lib/sign_in_session.dart.

import 'dart:convert';

import 'package:nerdster/app.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:nerdster_common/sign_in_session.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/keys.dart' show FedKey;
import 'package:oneofus_common/trust_statement.dart' show kOneofusDomain;

export 'package:nerdster_common/sign_in_session.dart';

Future<SignInSession> createNerdsterSignInSession() {
  final url = fireChoice == FireChoice.emulator
      ? 'http://10.0.2.2:5001/nerdster/us-central1/signin'
      : 'https://signin.nerdster.org/signin';
  return SignInSession.create(domain: kNerdsterDomain, signInUrl: url);
}

Future<void> nerdsterOnSessionData(Json data, PkeKeyPair pkeKeyPair,
    {SignInMethod method = SignInMethod.qrScan}) async {
  final String identityKey = data.containsKey('identity') ? 'identity' : kOneofusDomain;
  final Json identityPayload = data[identityKey]!;
  final FedKey fedKey = FedKey.fromPayload(identityPayload) ?? FedKey(identityPayload);
  final OouPublicKey oneofusPublicKey = await crypto.parsePublicKey(fedKey.pubKeyJson);

  OouKeyPair? nerdsterKeyPair;
  if (data['delegateCiphertext'] != null || data['delegateCleartext'] != null) {
    final String ephemeralPKKey = data.containsKey('ephemeralPK') ? 'ephemeralPK' : 'publicKey';
    final PkePublicKey phonePkePublicKey = await crypto.parsePkePublicKey(data[ephemeralPKKey]);

    String? delegateCleartext = data['delegateCleartext'];
    if (data['delegateCiphertext'] != null) {
      delegateCleartext = await pkeKeyPair.decrypt(data['delegateCiphertext'], phonePkePublicKey);
    }
    final Json delegateJson = jsonDecode(delegateCleartext!);
    nerdsterKeyPair = await crypto.parseKeyPair(delegateJson);
  }

  await signInUiHelper(oneofusPublicKey, nerdsterKeyPair,
      endpoint: fedKey.endpoint, method: method);
}
