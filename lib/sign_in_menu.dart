import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/net/key_lables.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in.dart';
import 'package:nerdster/sign_in_state.dart';

final KeyLabels _keyLabels = KeyLabels();
final SignInState _sign = SignInState();

class SignInMenu extends StatefulWidget {
  static const SignInMenu _singleton = SignInMenu._internal();
  factory SignInMenu() => _singleton;
  const SignInMenu._internal();

  @override
  State<StatefulWidget> createState() => _SignInMenuState();
}

class _SignInMenuState extends State<SignInMenu> {
  _SignInMenuState() {
    _sign.addListener(listen);
    _keyLabels.addListener(listen);
    listen();
  }

  Future<void> listen() async {
    await _keyLabels.waitUntilReady();
    setState(() {});
  }

  @override
  void dispose() {
    _sign.removeListener(listen);
    _keyLabels.removeListener(listen);
    super.dispose();
  }

  String label(String token) {
    String? netBaseLable = _keyLabels.labelKey(token);
    return b(netBaseLable) ? netBaseLable! : ' ? ';
  }

  @override
  Widget build(BuildContext context) {
    if (!Comp.compsReady([_keyLabels])) {
      return const Text('loading..');
    }
    String? centerLabel = label(_sign.center);

    String signedInLabel = ' - ';
    if (b(_sign.signedInOneofus)) {
      signedInLabel = label(_sign.signedInOneofus!);
    }

    String title = '[[ $signedInLabel / $centerLabel ]]';

    final StringBuffer status = StringBuffer();
    String viewingAs = 'Viewing as: "$centerLabel"';
    String? signedInAs = b(_sign.signedInOneofus) ? 'Signed in as: "$signedInLabel"' : null;
    if (!b(_sign.signedInOneofus)) {
      // not signed in
      status.write(viewingAs);
    } else if (_sign.signedInOneofus == _sign.center) {
      status.write('Signed in and viewing as: "$centerLabel"');
    } else {
      status.write(signedInAs);
      status.write(', ');
      status.write(viewingAs);
    }
    return SubmenuButton(
      menuChildren: [
        MenuItemButton(
            onPressed: () {},
            child: Row(
              children: [
                const Icon(Icons.login),
                Text(status.toString()),
              ],
            )),

        if (b(_sign.signedInOneofus) && _sign.signedInOneofus != _sign.center)
          MenuItemButton(
            onPressed: () {
              _sign.center = _sign.signedInOneofus!;
            },
            child: const Text('Center as yourself again'),
          ),

        // QR sign-in
        MenuItemButton(
            onPressed: () async {
              await qrSignin(context);
              // TODO: Store keys checkbox option
            },
            child: const Text('QR sign-in')),
        // copy/paste sign-in
        MenuItemButton(
            onPressed: () => pasteSignin(context), child: const Text('copy/paste sign-in')),
        MenuItemButton(
            onPressed: () async {
              await KeyStore.wipeKeys();
              await defaultSignIn();
            },
            child: const Text('Sign out')),
      ],
      child: Text(title),
    );
  }
}

Future<void> recenter(String token, BuildContext context) async {
  Widget w = const Text(
      '''Notice: You'll be viewing from a different perspective using a different network.
This network might know you by a different name, 
or might not even know you exist...''');

  // DEFER: Make less wide, maybe use text field instead of Text. BoxConstraints?
  return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
            child: Padding(
                padding: const EdgeInsets.all(15),
                child: SizedBox(
                    width: (MediaQuery.of(context).size).width / 2,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          w,
                          OkCancel(() async {
                            SignInState().center = token;
                            Navigator.pop(context);
                          }, 'Okay'),
                        ]))));
      });
}
