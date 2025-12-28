import 'package:flutter/material.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/credentials_display.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';

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
  
  // V2 views handle their own refresh via didUpdateWidget or listeners.
  // V1 still needs a manual refresh trigger.
  final path = Uri.base.path;
  final isV2 = path == '/' || path.contains('/v2/') || path == '/v2';
  if (!isV2) {
    await BarRefresh.refresh(context);
  }
}

class SignInState with ChangeNotifier {
  String? _pov;
  String? _identity;
  Json? _delegatePublicKeyJson;
  String? _delegate;
  StatementSigner? _signer;

  static final SignInState _singleton = SignInState._internal();

  SignInState._internal();
  factory SignInState() => _singleton;

  set pov(String? oneofusToken) {
    assert(b(Jsonish.find(oneofusToken!)));
    _pov = oneofusToken;
    // NEXT: Reconsider. Sometimes no one is signed in.
    // NEXT: show [pov, identity, delegate] in credentials display
    if (!b(_identity)) _identity = _pov; 
    notifyListeners();
  }

  Future<void> signIn(String identity, OouKeyPair? delegateKeyPair,
      {BuildContext? context}) async {
    _identity = identity;
    _pov = identity;
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
  String? get pov => _pov; // PoV, CODE: Maybe rename
  Json? get identityJson => b(identity) ? Jsonish.find(identity!)!.json : null;

  // derived
  String? get identity => _identity;
  Json? get delegatePublicKeyJson => _delegatePublicKeyJson;
  String? get delegate => _delegate;
  StatementSigner? get signer => _signer;
}
