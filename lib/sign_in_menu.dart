import 'package:flutter/material.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/credentials_display.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/main.dart';
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
    keyLabels.addListener(listen);
    listen();
  }

  Future<void> listen() async {
    await keyLabels.waitUntilReady();
    setState(() {});
  }

  @override
  void dispose() {
    signInState.removeListener(listen);
    keyLabels.removeListener(listen);
    super.dispose();
  }

  MenuItemButton showCredentials(BuildContext cnotext) {
    return MenuItemButton(
      leadingIcon: const Icon(Icons.account_circle),
      onPressed: () => showTopRightDialog(
          context,
          CredentialsDisplay(
              signInState.centerResetJson, signInState.signedInDelegatePublicKeyJson, showDontShow: false)),
      child: const Text('Show current sign-in credentials'),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool signedIn = b(signInState.signedInDelegate);

    if (signedIn) {
      return SplitMenuButton(
        label: 'Sign out',
        icon: const Icon(Icons.logout),
        onPrimary: () async {
          await KeyStore.wipeKeys();
          signInState.signOut(context: context);
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
                await signInState.signIn(key.token, nerdsterKeyPair, context: context);

                await BarRefresh.refresh(context);
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
            if (signInState.centerReset != null) showCredentials(context),
          ],
        );
      }
    }
  }
}
