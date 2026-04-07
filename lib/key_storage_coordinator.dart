import 'package:flutter/foundation.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/singletons.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';

/// Global "Store keys" preference. Defaults to true on every app start.
/// Toggling this immediately enforces the storage invariant via [KeyStorageCoordinator].
final ValueNotifier<bool> storeKeys = ValueNotifier(true);

/// Single place that calls [KeyStore]. Observes [signInState] and [storeKeys]
/// and enforces the Rep Invariant:
///   - storeKeys == true: the keys in memory match the stored keys (both identity and delegate)
///   - storeKeys == false: there are no stored keys.
///
/// Start via [KeyStorageCoordinator.instance.start()] early in app startup.
class KeyStorageCoordinator {
  KeyStorageCoordinator._();
  static final KeyStorageCoordinator instance = KeyStorageCoordinator._();

  void start() {
    signInState.addListener(_enforce);
    storeKeys.addListener(_enforce);
  }

  void dispose() {
    signInState.removeListener(_enforce);
    storeKeys.removeListener(_enforce);
  }

  void _enforce() {
    _enforceAsync();
  }

  Future<void> _enforceAsync() async {
    if (storeKeys.value && signInState.hasIdentity) {
      final idKey =
          await crypto.parsePublicKey(Jsonish.find(signInState.identity.value)!.json);
      await KeyStore.storeKeys(idKey, signInState.delegateKeyPair,
          endpoint: signInState.endpoint, method: signInState.signInMethod);
    } else {
      await KeyStore.wipeKeys();
    }
  }
}
