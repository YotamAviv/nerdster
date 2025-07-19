import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in.dart';

/// This has changed much over time, and so some docs, variable names, or worse might be misleading.
/// The idea is:
/// - center and signedIn are not always the same; viewing with a different center is a feature.
/// - in case you get far from home, we want to help you get back (currently, "<reset>")
class SignInState with ChangeNotifier {
  String? _center;
  String? _centerReset;
  OouKeyPair? _signedInDelegateKeyPair;
  OouPublicKey? _signedInDelegatePublicKey;
  Json? _signedInDelegatePublicKeyJson;
  String? _signedInDelegate;
  StatementSigner? _signer;

  static final SignInState _singleton = SignInState._internal();

  SignInState._internal();
  factory SignInState() => _singleton;

  set center(String? oneofusToken) {
    assert(b(Jsonish.find(oneofusToken!)));
    _center = oneofusToken;
    if (!b(_centerReset)) _centerReset = _center;
    notifyListeners();
  }

  // DEFER: "Don't show again..."
  // CONSIDER: Show credentials when changing PoV.

  Future<void> signIn(String center, OouKeyPair? nerdsterKeyPair, {BuildContext? context}) async {
    _center = center;
    _centerReset = center;
    if (b(nerdsterKeyPair)) {
      _signedInDelegateKeyPair = nerdsterKeyPair;
      _signedInDelegatePublicKey = await nerdsterKeyPair!.publicKey;
      _signedInDelegatePublicKeyJson = await _signedInDelegatePublicKey!.json;
      _signedInDelegate = getToken(_signedInDelegatePublicKeyJson);
      _signer = await OouSigner.make(nerdsterKeyPair);
    }

    if (b(context) && !b(Uri.base.queryParameters['skipCredentialsDisplay'])) {
      showTopRightDialog(
          context!, CredentialsWidget(centerResetJson, signedInDelegatePublicKeyJson));
    }

    notifyListeners();
  }

  void signOut({BuildContext? context}) {
    _signedInDelegateKeyPair = null;
    _signedInDelegatePublicKey = null;
    _signedInDelegatePublicKeyJson = null;
    _signedInDelegate = null;
    _signer = null;

    if (b(context)) {
      showTopRightDialog(
          context!, CredentialsWidget(centerResetJson, signedInDelegatePublicKeyJson));
    }

    notifyListeners();
  }

  String? get center => _center; // PoV, CODE: Maybe rename
  String? get centerReset => _centerReset; // signed in identity, CODE: Maybe rename
  Json? get centerResetJson => b(centerReset) ? Jsonish.find(centerReset!)!.json : null;
  OouKeyPair? get signedInDelegateKeyPair => _signedInDelegateKeyPair;
  OouPublicKey? get signedInDelegatePublicKey => _signedInDelegatePublicKey;
  Json? get signedInDelegatePublicKeyJson => _signedInDelegatePublicKeyJson;
  String? get signedInDelegate => _signedInDelegate;
  StatementSigner? get signer => _signer;
}
