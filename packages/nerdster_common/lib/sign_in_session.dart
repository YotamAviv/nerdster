import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';

class SignInSession {
  final PkeKeyPair pkeKeyPair;
  final String session;
  final Json forPhone;
  StreamSubscription? _subscription;
  Timer? _timeoutTimer;

  SignInSession._({required this.forPhone, required this.session, required this.pkeKeyPair});

  static Future<SignInSession> create({
    required String domain,
    required String signInUrl,
  }) async {
    final PkeKeyPair pkeKeyPair = await crypto.createPke();
    final PkePublicKey pkePK = await pkeKeyPair.publicKey;
    final Json pkePKJson = await pkePK.json;
    final String session = getToken(pkePKJson);

    final Json forPhone = {
      'domain': domain,
      'url': signInUrl,
      'encryptionPk': pkePKJson,
    };

    return SignInSession._(forPhone: forPhone, session: session, pkeKeyPair: pkeKeyPair);
  }

  /// Listens for the phone app's sign-in response in Firestore.
  /// Calls [onData] with the raw session document data when received.
  /// Calls [onDone] when the session is received or times out.
  Future<void> listen({
    required FirebaseFirestore firestore,
    required Future<void> Function(Json data, PkeKeyPair pkeKeyPair) onData,
    required void Function() onDone,
    Duration? timeout,
  }) async {
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
        .listen((QuerySnapshot<Json> snapshots) async {
      if (snapshots.docs.isEmpty) return;

      _timeoutTimer?.cancel();
      await cancel();
      onDone();

      await Future.delayed(const Duration(milliseconds: 300));
      await onData(snapshots.docs.first.data(), pkeKeyPair);
    });
  }

  Future<void> cancel() async {
    _timeoutTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }
}
