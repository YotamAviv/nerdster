import 'package:flutter/foundation.dart';
import 'package:oneofus_common/clock.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/singletons.dart';

// Yotam's public identity key — hardcoded as the root of the bootstrap network.
// The bootstrap identity locally vouches for this key so the user sees Yotam's
// trusted network without publishing anything.
const Json _kYotamPublicKey = {
  "crv": "Ed25519",
  "kty": "OKP",
  "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo",
};

/// Builds the two local-only statements needed for bootstrap:
///   1. A trust statement: bootstrapIdentity trusts Yotam
///   2. A delegate statement: bootstrapIdentity delegates bootstrapDelegate to nerdster.org
///
/// These are injected into TrustPipeline.localStatements — they are never published.
Future<Map<IdentityKey, List<TrustStatement>>> buildBootstrapLocalStatements({
  required OouKeyPair identityKeyPair,
  required OouKeyPair delegateKeyPair,
}) async {
  final OouPublicKey identityPublicKey = await identityKeyPair.publicKey;
  final OouPublicKey delegatePublicKey = await delegateKeyPair.publicKey;

  final Json identityPublicKeyJson = await identityPublicKey.json;
  final Json delegatePublicKeyJson = await delegatePublicKey.json;

  final signer = await OouSigner.make(identityKeyPair);

  // Build both statement JSONs with explicitly distinct timestamps.
  // TrustStatement.make() stamps 'time' via clock.nowIso.  JavaScript timer resolution
  // in Chrome can be coarser than 1ms, so we can't rely on a sleep — instead we
  // temporarily override the clock to guarantee strictly-descending order.
  // The trust statement must have a LATER time than the delegate statement (list is newest-first).
  final DateTime t0 = clock.now;
  final DateTime t1 = t0.subtract(const Duration(milliseconds: 1));

  // 1. Trust statement (newer — index 0)
  useClock(_FixedClock(t0));
  final Json trustJson = TrustStatement.make(
    identityPublicKeyJson,
    _kYotamPublicKey,
    TrustVerb.trust,
    moniker: 'Yotam',
  );

  // 2. Delegate statement (older — index 1)
  useClock(_FixedClock(t1));
  final Json delegateJson = TrustStatement.make(
    identityPublicKeyJson,
    delegatePublicKeyJson,
    TrustVerb.delegate,
    domain: kNerdsterDomain,
  );

  // Restore the live clock
  useClock(LiveClock());

  final Jsonish trustJsonish = await Jsonish.makeSign(trustJson, signer);
  final TrustStatement trustStatement = TrustStatement(trustJsonish);

  final Jsonish delegateJsonish = await Jsonish.makeSign(delegateJson, signer);
  final TrustStatement delegateStatement = TrustStatement(delegateJsonish);

  final IdentityKey bootstrapIdentityKey = IdentityKey(getToken(identityPublicKeyJson));

  // List is newest-first (trust at t0 is newer than delegate at t1).
  return {
    bootstrapIdentityKey: [trustStatement, delegateStatement],
  };
}

/// Called when the user taps "Bootstrap Quick Start".
/// Generates fresh key pairs, builds local statements, persists to secure storage,
/// and signs in.
Future<void> bootstrapSignIn() async {
  // Generate fresh Ed25519 key pairs
  final OouKeyPair identityKeyPair = await crypto.createKeyPair();
  final OouKeyPair delegateKeyPair = await crypto.createKeyPair();

  // Persist for app-restart recovery
  await KeyStore.storeBootstrapKeys(identityKeyPair, delegateKeyPair);

  // Sign in
  await _doBootstrapSignIn(identityKeyPair, delegateKeyPair);
}

/// Called on app startup when bootstrap flag is detected — restores bootstrap mode
/// from persisted keys.
Future<bool> restoreBootstrapIfNeeded() async {
  final keys = await KeyStore.readBootstrapKeys();
  if (keys == null) return false;
  final (identityKeyPair, delegateKeyPair) = keys;
  await _doBootstrapSignIn(identityKeyPair, delegateKeyPair);
  return true;
}

Future<void> _doBootstrapSignIn(
    OouKeyPair identityKeyPair, OouKeyPair delegateKeyPair) async {
  final OouPublicKey identityPublicKey = await identityKeyPair.publicKey;
  final Json identityPublicKeyJson = await identityPublicKey.json;
  final String identityToken = getToken(identityPublicKeyJson);

  // Build local statements and register them globally so FeedController picks them up.
  final localStatements = await buildBootstrapLocalStatements(
    identityKeyPair: identityKeyPair,
    delegateKeyPair: delegateKeyPair,
  );
  bootstrapLocalStatements.value = localStatements;

  await signInState.signIn(identityToken, delegateKeyPair);
}

/// Global notifier holding local statements for bootstrap mode.
/// FeedController reads this when building TrustPipeline.
/// Empty when not in bootstrap mode.
final ValueNotifier<Map<IdentityKey, List<TrustStatement>>> bootstrapLocalStatements =
    ValueNotifier(const {});

/// Set to true when ?iphone=true is in the URL, simulating iPhone UX on other platforms.
/// Causes the sign-in dialog to show the "Bootstrap Quick Start" button.
bool forceIphone = false;

/// Clears bootstrap mode. Also signs out — bootstrap identity is meaningless without local statements.
Future<void> clearBootstrap() async {
  bootstrapLocalStatements.value = const {};
  await KeyStore.clearBootstrapKeys();
  if (signInState.isSignedIn) {
    signInState.signOut(clearIdentity: true);
  }
}

/// A fixed-time Clock used to stamp two bootstrap statements with distinct timestamps.
class _FixedClock extends Clock {
  final DateTime _time;
  _FixedClock(this._time);
  @override
  DateTime get now => _time;
}
