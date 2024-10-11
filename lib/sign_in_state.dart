import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/util.dart';

/// NetBase tracks the signed in Oneofus key (signedInOneofus) specifically because DelegateNetwork
/// might not know delegate2oneofus for that nerd when viewing as someone else.
/// If you started off centered on me (Yotam) by default, then you were never signed in as yourself, and
/// you probably shouldn't be able to go back to Yotam other than just reloading.
/// But if you signed in with a delegate and Oneofus key (that matched), then you were signed in, and we
/// should remember that Oneofus key which you should be able to return to.

class SignInState with ChangeNotifier {
  String _center;
  String? _signedInOneofus; // only set if you 'signed in' using a delegate key
  OouKeyPair? _signedInDelegateKeyPair;
  OouPublicKey? _signedInDelegatePublicKey;
  Json? _signedInDelegatePublicKeyJson;
  String? _signedInDelegate;
  StatementSigner? _signer;

  static SignInState? _singleton;

  SignInState.init(this._center) {
    assert(!b(_singleton));
    _singleton = this;
  }

  factory SignInState() => _singleton!;

  set center(String oneofusToken) {
    _center = oneofusToken;
    notifyListeners();
  }

  Future<void> signIn(OouKeyPair nerdsterKeyPair) async {
    _signedInOneofus = _center;
    _signedInDelegateKeyPair = nerdsterKeyPair;
    _signedInDelegatePublicKey = await nerdsterKeyPair.publicKey;
    _signedInDelegatePublicKeyJson = await _signedInDelegatePublicKey!.json;
    _signedInDelegate = getToken(await _signedInDelegatePublicKey!.json);
    _signer = await OouSigner.make(nerdsterKeyPair);
    notifyListeners();
  }

  Future<void> centerAndSignIn(String oneofusToken, OouKeyPair nerdsterKeyPair) async {
    _center = oneofusToken;
    // NOTE: Below would call notifyListeners() ahead of async gaps; should work, but used to cause deadlock.
    // center = oneofusToken; 

    _signedInOneofus = _center;
    _signedInDelegateKeyPair = nerdsterKeyPair;
    _signedInDelegatePublicKey = await nerdsterKeyPair.publicKey;
    _signedInDelegatePublicKeyJson = await _signedInDelegatePublicKey!.json;
    _signedInDelegate = getToken(await _signedInDelegatePublicKey!.json);
    _signer = await OouSigner.make(nerdsterKeyPair);

    notifyListeners();
  }

  void signOut() {
    _signedInOneofus = null;
    _signedInDelegateKeyPair = null;
    _signedInDelegatePublicKey = null;
    _signedInDelegatePublicKeyJson = null;
    _signedInDelegate = null;
    _signer = null;
    notifyListeners();
  }

  String get center => _center;
  String? get signedInOneofus => _signedInOneofus;
  OouKeyPair? get signedInDelegateKeyPair => _signedInDelegateKeyPair;
  OouPublicKey? get signedInDelegatePublicKey => _signedInDelegatePublicKey;
  Json? get signedInDelegatePublicKeyJson => _signedInDelegatePublicKeyJson;
  String? get signedInDelegate => _signedInDelegate;
  StatementSigner? get signer => _signer;
}
