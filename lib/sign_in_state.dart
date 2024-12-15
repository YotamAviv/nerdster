import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

/// This has changed much over time, and so some docs, variable names, or worse might be misleading.
/// This class may not even be necessary.
/// The idea is:
/// - center and signedIn are not always the same; viewing with a different center is a feature.
/// - in case you get far from home, we want to help you get back (currently, "<reset>")
class SignInState with ChangeNotifier {
  String _center;
  late String _centerReset;
  OouKeyPair? _signedInDelegateKeyPair;
  OouPublicKey? _signedInDelegatePublicKey;
  Json? _signedInDelegatePublicKeyJson;
  String? _signedInDelegate;
  StatementSigner? _signer;

  static SignInState? _singleton;

  SignInState.init(this._center) {
    assert(!b(_singleton));
    _centerReset = _center;
    _singleton = this;
  }

  factory SignInState() => _singleton!;

  set center(String oneofusToken) {
    _center = oneofusToken;
    notifyListeners();
  }

  Future<void> signIn(OouKeyPair nerdsterKeyPair, String center) async {
    _signedInDelegateKeyPair = nerdsterKeyPair;
    _signedInDelegatePublicKey = await nerdsterKeyPair.publicKey;
    _signedInDelegatePublicKeyJson = await _signedInDelegatePublicKey!.json;
    _signedInDelegate = getToken(await _signedInDelegatePublicKey!.json);
    _signer = await OouSigner.make(nerdsterKeyPair);

    _center = center;
    _centerReset = center;

    notifyListeners();

    // Check if delegate is delegate of Oneofus
    await Comp.waitOnComps([followNet]);
    if (followNet.delegate2oneofus[_signedInDelegate] != _center) {
      print('************ followNet.delegate2oneofus[_signedInDelegate] != _center ************');
    }
  }

  void signOut() {
    _signedInDelegateKeyPair = null;
    _signedInDelegatePublicKey = null;
    _signedInDelegatePublicKeyJson = null;
    _signedInDelegate = null;
    _signer = null;
    notifyListeners();
  }

  String get center => _center;
  String? get centerReset => _centerReset;
  OouKeyPair? get signedInDelegateKeyPair => _signedInDelegateKeyPair;
  OouPublicKey? get signedInDelegatePublicKey => _signedInDelegatePublicKey;
  Json? get signedInDelegatePublicKeyJson => _signedInDelegatePublicKeyJson;
  String? get signedInDelegate => _signedInDelegate;
  StatementSigner? get signer => _signer;
}
