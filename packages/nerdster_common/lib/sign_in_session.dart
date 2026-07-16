import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';

/// How the user signed in — which transport they used to hand data to the identity app.
/// Persisted by the app, then reused to hand block/clear intentions to the same app ("pass
/// the intention"): the sign-in dialog emits this, block/clear reads it back. A null
/// SignInMethod (this is always used as `SignInMethod?`) means we don't know if or how the
/// user signed in, so block/clear cannot be offered. See doc/pass_the_intention.md
/// (nerdster repo).
enum SignInMethod {
  keymeid,    // keymeid:// custom scheme (same device); the app-neutral scheme
  oneOfUsNet, // https://one-of-us.net/... universal link (same device); the default
  qrScan,     // QR code scanned by the identity app on a different device
  paste,      // JSON credentials pasted; hidden debug-only path, dialog never emits it
}

class SignInSession {
  final PkeKeyPair pkeKeyPair;
  final OouKeyPair serviceKeyPair;
  final String session;
  final Json forPhone;
  StreamSubscription? _subscription;
  Timer? _timeoutTimer;

  SignInSession._({required this.forPhone, required this.session, required this.pkeKeyPair, required this.serviceKeyPair});

  static Future<SignInSession> create({
    required String domain,
    required String signInUrl,
  }) async {
    final PkeKeyPair pkeKeyPair = await crypto.createPke();
    final PkePublicKey pkePK = await pkeKeyPair.publicKey;
    final Json pkePKJson = await pkePK.json;
    final String session = getToken(pkePKJson);

    final OouKeyPair serviceKeyPair = await crypto.createKeyPair();
    final OouPublicKey servicePK = await serviceKeyPair.publicKey;
    final Json servicePKJson = await servicePK.json;

    final Json forPhone = {
      'domain': domain,
      'url': signInUrl,
      'servicePk': servicePKJson,
      'encryptionPk': pkePKJson,
    };

    return SignInSession._(forPhone: forPhone, session: session, pkeKeyPair: pkeKeyPair, serviceKeyPair: serviceKeyPair);
  }

  /// Listens for the phone app's sign-in response in Firestore.
  /// Calls [onData] with the raw session document data when received.
  /// Calls [onDone] when the session is received or times out.
  Future<void> listen({
    required FirebaseFirestore firestore,
    required Future<void> Function(Json data, PkeKeyPair pkeKeyPair, OouKeyPair serviceKeyPair) onData,
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
      await onData(snapshots.docs.first.data(), pkeKeyPair, serviceKeyPair);
    });
  }

  Future<void> cancel() async {
    _timeoutTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }
}
