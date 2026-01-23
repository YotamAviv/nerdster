import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in_state.dart';

class SignInSession {
  final PkeKeyPair pkeKeyPair;
  final String session;
  final Json forPhone;
  StreamSubscription? _subscription;
  Timer? _timeoutTimer;

  SignInSession({required this.forPhone, required this.session, required this.pkeKeyPair});

  static Future<SignInSession> create() async {
    Json forPhoneV2 = {};
    forPhoneV2['domain'] = kNerdsterDomain;

    forPhoneV2['url'] = 'https://signin.nerdster.org/signin';
    if (fireChoice == FireChoice.emulator) {
      // Use 10.0.2.2 (not 127.0.0.1) for Android Emulator to access host machine localhost
      forPhoneV2['url'] = 'http://10.0.2.2:5001/nerdster/us-central1/signin';
    }

    final PkeKeyPair pkeKeyPair = await crypto.createPke();
    final PkePublicKey pkePK = await pkeKeyPair.publicKey;
    var pkePKJson = await pkePK.json;
    final String session = getToken(pkePKJson);
    forPhoneV2['encryptionPk'] = pkePKJson;

    return SignInSession(
      forPhone: forPhoneV2,
      session: session,
      pkeKeyPair: pkeKeyPair,
    );
  }

  Future<void> listen({
    required Function() onDone,
    Duration? timeout,
    required ValueNotifier<bool> storeKeys,
  }) async {
    final firestore = FirebaseFirestore.instance;

    if (timeout != null) {
      _timeoutTimer = Timer(timeout, () {
        cancel();
        onDone();
      });
    }

    _subscription = firestore
        .collection('sessions')
        .doc('doc')
        .collection(session)
        .snapshots()
        .listen((QuerySnapshot<Json> docSnapshots) async {
      if (docSnapshots.docs.isEmpty) return;

      // Found data, stop listening and timeout
      _timeoutTimer?.cancel();
      await cancel();

      // Notify UI to close dialogs first, so animation is visible on the underlying screen
      onDone();

      // Wait for dialog close animation
      await Future.delayed(const Duration(milliseconds: 300));

      Json? data = docSnapshots.docs.first.data();

      // Unpack identity public key
      final String identityKey = data.containsKey('identity') ? 'identity' : kOneofusDomain;
      Json identityJson = data[identityKey]!;
      OouPublicKey oneofusPublicKey = await crypto.parsePublicKey(identityJson);

      // Optionally unpack and decrypt Nerdster private key
      Json? delegateJson;
      OouKeyPair? nerdsterKeyPair;
      if (b(data['delegateCiphertext']) || b(data['delegateCleartext'])) {
        final String ephemeralPKKey = data.containsKey('ephemeralPK') ? 'ephemeralPK' : 'publicKey';
        PkePublicKey phonePkePublicKey = await crypto.parsePkePublicKey(data[ephemeralPKKey]);

        String? delegateCiphertext = data['delegateCiphertext'];
        String? delegateCleartext = data['delegateCleartext'];
        assert(!(b(delegateCiphertext) && b(delegateCleartext)));
        if (b(delegateCiphertext)) {
          delegateCleartext = await pkeKeyPair.decrypt(delegateCiphertext!, phonePkePublicKey);
        }
        delegateJson = jsonDecode(delegateCleartext!);
        nerdsterKeyPair = await crypto.parseKeyPair(delegateJson!);
      }

      await signInUiHelper(oneofusPublicKey, nerdsterKeyPair, storeKeys.value);
    });
  }

  Future<void> cancel() async {
    _timeoutTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }
}
