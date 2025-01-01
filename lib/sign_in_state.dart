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
  static final String _dummy = Jsonish({}).token;
  String _center = _dummy;
  String _centerReset = _dummy;
  OouKeyPair? _signedInDelegateKeyPair;
  OouPublicKey? _signedInDelegatePublicKey;
  Json? _signedInDelegatePublicKeyJson;
  String? _signedInDelegate;
  StatementSigner? _signer;

  static final SignInState _singleton = SignInState._internal();

  SignInState._internal();
  factory SignInState() => _singleton;

  set center(String oneofusToken) {
    _center = oneofusToken;
    if (_centerReset == _dummy) _centerReset = _center;
    notifyListeners();
  }

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

    // Check if delegate is delegate of Oneofus
    await Comp.waitOnComps([followNet]);
    if (followNet.delegate2oneofus[_signedInDelegate] != _center) {
      print('********** ${followNet.delegate2oneofus[_signedInDelegate]} != $_center **********');
      print('********** followNet.delegate2oneofus[_signedInDelegate] != _center **********');
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
