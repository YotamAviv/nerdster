import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/util.dart';

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

  // NEXT: pass in context?, show credentials
  // NEXT: "Don't show again..."
  // NEXT: Show for changing PoV.

  Future<void> signIn(String center, OouKeyPair? nerdsterKeyPair) async {
    _center = center;
    _centerReset = center;
    if (b(nerdsterKeyPair)) {
      _signedInDelegateKeyPair = nerdsterKeyPair;
      _signedInDelegatePublicKey = await nerdsterKeyPair!.publicKey;
      _signedInDelegatePublicKeyJson = await _signedInDelegatePublicKey!.json;
      _signedInDelegate = getToken(_signedInDelegatePublicKeyJson);
      _signer = await OouSigner.make(nerdsterKeyPair);
    }
    notifyListeners();
  }

  // NEXT: pass in context?, show credentials
  void signOut() {
    _signedInDelegateKeyPair = null;
    _signedInDelegatePublicKey = null;
    _signedInDelegatePublicKeyJson = null;
    _signedInDelegate = null;
    _signer = null;
    notifyListeners();
  }

  String? get center => _center; // CODE: Maybe rename to "pov"
  String? get centerReset => _centerReset; // CODE: Maybe rename to "identity"
  OouKeyPair? get signedInDelegateKeyPair => _signedInDelegateKeyPair;
  OouPublicKey? get signedInDelegatePublicKey => _signedInDelegatePublicKey;
  Json? get signedInDelegatePublicKeyJson => _signedInDelegatePublicKeyJson;
  String? get signedInDelegate => _signedInDelegate;
  StatementSigner? get signer => _signer;
}
