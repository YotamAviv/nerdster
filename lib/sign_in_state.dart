import 'package:flutter/material.dart';
import 'package:nerdster/credentials_display.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';


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

Future<void> signInUiHelper(OouPublicKey oneofusPublicKey, OouKeyPair? nerdsterKeyPair, bool store,
    BuildContext context) async {
  if (store) {
    await KeyStore.storeKeys(oneofusPublicKey, nerdsterKeyPair);
  } else {
    await KeyStore.wipeKeys();
  }

  final String oneofusToken = getToken(await oneofusPublicKey.json);
  await signInState.signIn(oneofusToken, nerdsterKeyPair, context: context);
}

class SignInState with ChangeNotifier {
  final ValueNotifier<String?> povNotifier = ValueNotifier<String?>(null);
  String? _identity;
  Json? _delegatePublicKeyJson;
  String? _delegate;
  StatementSigner? _signer;

  static final SignInState _singleton = SignInState._internal();

  SignInState._internal();
  factory SignInState() => _singleton;

  set pov(String? oneofusToken) {
    if (oneofusToken != null) {
      assert(b(Jsonish.find(oneofusToken)));
    }
    povNotifier.value = oneofusToken;
    // CONSIDER: show [pov, identity, delegate] in credentials display
    if (!b(_identity)) _identity = povNotifier.value; 
    notifyListeners();
  }

  Future<void> signIn(String identity, OouKeyPair? delegateKeyPair,
      {BuildContext? context}) async {
    _identity = identity;
    povNotifier.value = identity;
    if (b(delegateKeyPair)) {
      OouPublicKey delegatePublicKey = await delegateKeyPair!.publicKey;
      _delegatePublicKeyJson = await delegatePublicKey.json;
      _delegate = getToken(_delegatePublicKeyJson);
      _signer = await OouSigner.make(delegateKeyPair);
    }

    if (b(context) &&
        !Uri.base.queryParameters.containsKey('skipCredentialsDisplay') &&
        !Setting.get<bool>(SettingType.skipCredentials).value) {
      showTopRightDialog(
          context!, CredentialsDisplay(identityJson, delegatePublicKeyJson));
    }

    notifyListeners();
  }

  void signOut({bool? clearIdentity = false, BuildContext? context}) {
    if (clearIdentity == true) _identity = null;
    _delegatePublicKeyJson = null;
    _delegate = null;
    _signer = null;

    if (b(context) && !Setting.get<bool>(SettingType.skipCredentials).value) {
      showTopRightDialog(
          context!, CredentialsDisplay(identityJson, delegatePublicKeyJson));
    }

    notifyListeners();
  }

  // inputs
  String? get pov => povNotifier.value;
  Json? get identityJson => b(identity) ? Jsonish.find(identity!)!.json : null;

  // derived
  String? get identity => _identity;
  Json? get delegatePublicKeyJson => _delegatePublicKeyJson;
  String? get delegate => _delegate;
  StatementSigner? get signer => _signer;
}
