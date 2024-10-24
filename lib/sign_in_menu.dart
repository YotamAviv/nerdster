import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:nerdster/singletons.dart';

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
    if (!Comp.compsReady([keyLabels])) {
      return const Text('loading..');
    }
    String? centerLabel = label(signInState.center);

    String signedInLabel = ' - ';
    if (b(signInState.signedInOneofus)) {
      signedInLabel = label(signInState.signedInOneofus!);
    }

    final StringBuffer status = StringBuffer();
    String viewingAs = 'Viewing as: "$centerLabel"';
    String? signedInAs = b(signInState.signedInOneofus) ? 'Signed in as: "$signedInLabel"' : null;
    if (!b(signInState.signedInOneofus)) {
      // not signed in
      status.write(viewingAs);
    } else if (signInState.signedInOneofus == signInState.center) {
      status.write('Signed in and viewing as: "$centerLabel"');
    } else {
      status.write(signedInAs);
      status.write(', ');
      status.write(viewingAs);
    }
    return SubmenuButton(
      menuChildren: [
        if (b(signInState.signedInOneofus) && signInState.signedInOneofus != signInState.center)
          MenuItemButton(
            onPressed: () {
              signInState.center = signInState.signedInOneofus!;
            },
            child: const Text('Center as yourself again'),
          ),

        // QR sign-in
        MenuItemButton(
            onPressed: () async {
              await qrSignin(context);
              // TODO: Store keys checkbox option
            },
            child: const Row(children: [
              Icon(Icons.login),
              Text('QR sign-in'),
            ])),
        // copy/paste sign-in
        MenuItemButton(
            onPressed: () => pasteSignin(context),
            child: const Row(children: [
              Icon(Icons.copy),
              Text('paste sign-in')])),
        MenuItemButton(
            onPressed: () async {
              await KeyStore.wipeKeys();
              signInState.signOut();
            },
            child: const Text('Sign out')),
      ],
      child: Text(status.toString()),
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
