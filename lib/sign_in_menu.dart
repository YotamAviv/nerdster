import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/credentials_display.dart';
import 'package:nerdster/demo_setup.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/paste_sign_in.dart';
import 'package:nerdster/qr_sign_in.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/split_menu_button.dart';

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
    // keyLabels.addListener(listen);
    listen();
  }

  Future<void> listen() async {
    // await keyLabels.waitUntilReady();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    signInState.removeListener(listen);
    // keyLabels.removeListener(listen);
    super.dispose();
  }

  MenuItemButton showCredentials(BuildContext context) {
    return MenuItemButton(
      leadingIcon: const Icon(Icons.account_circle),
      onPressed: () {
        final size = MediaQuery.of(context).size;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.white,
            closeIconColor: Colors.black,
            content: DefaultTextStyle(
                style: const TextStyle(color: Colors.black),
                child: CredentialsDisplay(
                    signInState.identityJson, signInState.delegatePublicKeyJson)),
            duration: const Duration(seconds: 10),
            showCloseIcon: false,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.only(left: size.width / 2, bottom: 20, right: 20),
          ),
        );
      },
      child: const Text('Show current sign-in credentials'),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool signedIn = b(signInState.delegate);

    if (signedIn) {
      return SplitMenuButton(
        label: 'Sign out',
        icon: const Icon(Icons.logout),
        onPrimary: () async {
          await KeyStore.wipeKeys();
          signInState.signOut();
        },
        menuChildren: [
          showCredentials(context),
        ],
      );
    } else {
      if (b(demo)) {
        List<Widget> demoSignIns = <Widget>[];
        for (final DemoKey key in DemoKey.all) {
          if (key.name.contains('-nerdster')) continue; // KLUGEY: Don't center as the delegate
          final String name = key.name;
          final DemoKey? delegateKey =
              DemoKey.findByName('$name-nerdster0'); // KLUGEY: and probably wrong
          final OouKeyPair? nerdsterKeyPair = delegateKey?.keyPair;
          demoSignIns.add(MenuItemButton(
              onPressed: () async {
                await signInState.signIn(key.token, nerdsterKeyPair);
              },
              child: Text(name)));
        }
        return SubmenuButton(menuChildren: demoSignIns, child: const Text('Demo sign-in'));
      } else {
        return SplitMenuButton(
          label: 'QR Sign in',
          icon: const Icon(Icons.qr_code),
          onPrimary: fireChoice != FireChoice.fake ? () => qrSignIn(context) : null,
          menuChildren: [
            MenuItemButton(
              leadingIcon: const Icon(Icons.copy),
              onPressed: () => pasteSignIn(context),
              child: const Text('Paste sign-in'),
            ),
            if (signInState.identity != null) showCredentials(context),
          ],
        );
      }
    }
  }
}
