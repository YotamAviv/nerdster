import 'package:flutter/foundation.dart';
import 'package:nerdster/singletons.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart' show FedKey, IdentityKey, kNativeEndpoint;
import 'package:oneofus_common/oou_signer.dart';

/// This class tracks the sign-in state of the user using 3 main variables:
/// - identity (an identity key token)
/// - pov (an identity key token)
/// - delegate (a delegate key token)
/// The PoV is expected to change during their session.
///
/// identity: The identity key token that represents who you are. This is the key you signed in with.
/// PoV: The point-of-view key token that represents whose perspective you are using to view the site.
///       This may be the same as identity, or it may be different (e.g., you are viewing as someone you trust).
/// identity is used in few places, where we want to know who you are.
/// - reset (if you change PoV and want to go back to your identity)
/// - to show you your own content when you are using a different PoV and bring up the RateDialog, RelateDialog, edit you follows, etc.
/// PoV is used everywhere else, to determine what content you see.
/// If you are signed in with a delegate key, then it necessarily should be associated with your identity.
///
/// Summary of Roles:
/// 1. PoV (Point of View): The **Read Context**.
///    - Determines the "World" the user is looking at.
///    - Drives the Trust Graph, Follow Network, and Content Aggregation.
///    - Answers "What content is visible?" and "How is it ranked?".
///
/// 2. Identity: The **Write Context** and **Self-Reflection**.
///    - Represents the active user.
///    - Used ONLY to:
///      * Allow the user to return to their own view (`reset`).
///      * Overlay the user's own state on top of the PoV's world (e.g., showing "You rated this" in a dialog).
///      * Authorize actions (signing statements).
///
/// 3. Identity without Delegate (View-Only Identity):
///    It is possible to have an `identity` set but NOT be signed in with a `delegate` key.
///    This happens when:
///    - Identity is provided in the URL (e.g. deep link).
///    - User signs in (via phone app or copy/paste) but does not provide a delegate key.
///    In this state, the user can see their own content (Self-Reflection) but cannot perform write actions.
///

/// Considerations:
/// - Signing in is signing in. The user clicked "sign-in", and submitted an identity. We have
///   identity and PoV.
/// - Loading a page that passes in the PoV is not signing in. We have a PoV for sure, but maybe
///   we shouldn't assume that we have identity.
/// - In case you get far from home or reach a dead end (PoV trusts no one), we want to help you
///   get back (currently, "<reset>")
/// It seems that we only use identity for notifications, and some of those might be suspect. PoV
/// rules.
/// <reset> currently brings you back to identity, but I'm contemplating allowing that to be null,
/// in which case we might need a "firstPov" or "povReset"
///
/// UI tech
/// I'm considering making PoV and maybe even identity a Setting. This might add elegence or
/// klugeyness.
/// I'd like to allow a page (nerdster.org/home.html, aviv.net) let you change settings, and it'd be
/// nice to have Progress. One way to achieve that would be to have the UI watch those notifiers in
/// StatefulWidgets.

/// How the user signed into Nerdster. Determines the "pass the intention" handoff
/// strategy for identity-layer actions (trust/block/clear).
enum SignInMethod {
  keymeid,    // keymeid:// button in the sign-in widget
  oneOfUsNet, // https://one-of-us.net button in the sign-in widget
  qrScan,     // QR code scanned by the ONE-OF-US phone app
  paste,      // JSON credentials pasted
  url,        // Sign in via ?identity=... URL parameter
}

Future<void> signInUiHelper(
    OouPublicKey oneofusPublicKey, OouKeyPair? nerdsterKeyPair,
    {Map<String, dynamic> endpoint = kNativeEndpoint, SignInMethod? method}) async {
  final fedKey = FedKey(await oneofusPublicKey.json, endpoint);
  await signInState.signInWithFedKey(fedKey, nerdsterKeyPair, method: method);
}

class SignInState with ChangeNotifier {
  final ValueNotifier<String?> povNotifier = ValueNotifier<String?>(null);
  IdentityKey? _identity;
  Json? _delegatePublicKeyJson;
  String? _delegate;
  StatementSigner? _signer;
  OouKeyPair? _delegateKeyPair;
  Map<String, dynamic> _endpoint = kNativeEndpoint;
  SignInMethod? _signInMethod;

  static final SignInState _singleton = SignInState._internal();

  SignInState._internal();
  factory SignInState() => _singleton;

  set pov(String oneofusToken) {
    assert(Jsonish.find(oneofusToken) != null);
    povNotifier.value = oneofusToken;
    // CONSIDER: show [pov, identity, delegate] in credentials display
    notifyListeners();
  }

  Future<void> signInWithFedKey(FedKey fedKey, OouKeyPair? delegateKeyPair,
      {SignInMethod? method}) async {
    _identity = fedKey.identityKey;
    _endpoint = fedKey.endpoint;
    _signInMethod = method;
    povNotifier.value = fedKey.identityKey.value;
    _delegateKeyPair = delegateKeyPair;
    if (delegateKeyPair != null) {
      OouPublicKey delegatePublicKey = await delegateKeyPair.publicKey;
      _delegatePublicKeyJson = await delegatePublicKey.json;
      _delegate = getToken(_delegatePublicKeyJson);
      _signer = await OouSigner.make(delegateKeyPair);
    } else {
      _delegatePublicKeyJson = null;
      _delegate = null;
      _signer = null;
    }

    notifyListeners();
  }

  @Deprecated('Use signInWithFedKey instead')
  Future<void> signIn(String identity, OouKeyPair? delegateKeyPair) async {
    final fedKey = FedKey.fromPayload(Jsonish.find(identity)!.json)!;
    await signInWithFedKey(fedKey, delegateKeyPair);
  }

  void signOut({bool? clearIdentity = false}) {
    if (clearIdentity == true) {
      if (povNotifier.value == _identity?.value) povNotifier.value = null;
      _identity = null;
    }
    _delegatePublicKeyJson = null;
    _delegate = null;
    _signer = null;
    _delegateKeyPair = null;
    _signInMethod = null;

    notifyListeners();
  }

  // inputs
  String get pov {
    if (povNotifier.value != null) return povNotifier.value!;
    if (_identity == null) throw StateError("Accessed pov before sign in");
    return _identity!.value;
  }

  Json get identityJson => Jsonish.find(identity.value)!.json;

  // derived
  /// True when the user has a PoV — sufficient to view content.
  /// Identity may still be null (e.g. arrived via a shared Nerdster link).
  bool get hasPov => povNotifier.value != null;

  /// True when the user has actively identified themselves.
  /// Required for write operations and self-reflection (e.g. "this is you").
  bool get hasIdentity => _identity != null;

  IdentityKey get identity {
    if (_identity == null) throw StateError("Accessed identity before sign in");
    return _identity!;
  }

  Json? get delegatePublicKeyJson => _delegatePublicKeyJson;
  String? get delegate => _delegate;
  StatementSigner? get signer => _signer;
  OouKeyPair? get delegateKeyPair => _delegateKeyPair;
  Map<String, dynamic> get endpoint => _endpoint;
  SignInMethod? get signInMethod => _signInMethod;
}
