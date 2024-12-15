import 'package:flutter/material.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/menus.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in.dart';
import 'package:nerdster/singletons.dart';

/// CONSIDER: Display (instead of imply) 'not signed in'.
class SignInMenu extends StatefulWidget {
  static const SignInMenu _singleton = SignInMenu._internal();
  factory SignInMenu() => _singleton;
  const SignInMenu._internal();

  @override
  State<StatefulWidget> createState() => _SignInMenuState();
}

class _SignInMenuState extends State<SignInMenu> {
  _SignInMenuState() {
    signInState.addListener(listen);
    keyLabels.addListener(listen);
    listen();
  }

  Future<void> listen() async {
    await keyLabels.waitUntilReady();
    // bad, null: print('_SignInMenuState.listen(keyLabels): ${BarRefresh.stopwatch!.elapsed}');
    setState(() {});
  }

  @override
  void dispose() {
    signInState.removeListener(listen);
    keyLabels.removeListener(listen);
    super.dispose();
  }

  String label(String token) {
    String? netBaseLable = keyLabels.labelKey(token);
    return b(netBaseLable) ? netBaseLable! : ' ? ';
  }

  @override
  Widget build(BuildContext context) {
    bool signedIn = b(signInState.signedInDelegate);

    if (signedIn) {
      return MenuItemButton(
          onPressed: () async {
            await KeyStore.wipeKeys();
            signInState.signOut();
          },
          child: const Row(
            children: [
              Icon(Icons.logout),
              iconSpacer,
              Text('Sign out'),
            ],
          ));
    } else {
      return SubmenuButton(
          menuChildren: [
            // QR sign-in
            MenuItemButton(
                onPressed: () => qrSignin(context),
                child: const Row(children: [
                  Icon(Icons.qr_code),
                  iconSpacer,
                  Text('QR sign-in'),
                ])),
            // copy/paste sign-in
            MenuItemButton(
                onPressed: () => pasteSignin(context),
                child: const Row(children: [
                  Icon(Icons.copy),
                  iconSpacer,
                  Text('paste sign-in'),
                ])),
          ],
          child: const Row(
            children: [
              Icon(Icons.login),
              iconSpacer,
              Text('Sign in'),
            ],
          ));
    }
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
                            signInState.center = token;
                            Navigator.pop(context);
                          }, 'Okay'),
                        ]))));
      });
}
