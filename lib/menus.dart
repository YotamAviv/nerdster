import 'package:flutter/material.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/dump_all_statements.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/nerdster_link.dart';
import 'package:nerdster/net/oneofus_equiv.dart';
import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/sign_in_menu.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/tokenize.dart';

// SchedulerBinding.instance.addPostFrameCallback((_) async {
// });
// Future.delayed(const Duration(seconds: 1), () async {
// });

const iconSpacer = SizedBox(width: 3);

class Menus {
  static List<Widget> build(context) {
    List<Widget> demos = <Widget>[];
    for (final e in DemoKey.demos.entries) {
      demos.add(MenuItemButton(
          onPressed: () async {
            DemoKey.clear();
            DemoKey? oneofus, delegate;
            (oneofus, delegate) = await e.value();
            await printDemoCredentials(oneofus!, delegate);
            if (!b(delegate)) {
              signInState.center = oneofus.token;
            } else {
              await signInState.signIn(oneofus.token, delegate!.keyPair);
            }
          },
          child: Text(e.key)));
    }

    List<Widget> demoSignins = <Widget>[];
    for (final DemoKey key in DemoKey.all) {
      if (key.name.contains('-nerdster')) {
        continue; // KLUGEY: Don't center as the delegate
      }
      final String name = key.name;
      final DemoKey? delegateKey = DemoKey.findByName('$name-nerdster0'); // KLUGEY:
      final OouKeyPair? nerdsterKeyPair = delegateKey?.keyPair;
      demoSignins.add(MenuItemButton(
          onPressed: () async {
            await printDemoCredentials(key, delegateKey);
            await signInState.signIn(key.token, nerdsterKeyPair);
            await OneofusEquiv().waitUntilReady();
          },
          child: Text(name)));
    }

    return <Widget>[
      SignInMenu(),

      // Prefs
      SubmenuButton(
          menuChildren: <Widget>[
            MyCheckbox(Prefs.nice, 'translate <JSON> and token gibberish'),
            MyCheckbox(Prefs.showJson, 'show JSON'),
            MyCheckbox(Prefs.showKeys, 'show equivalent keys'),
            MyCheckbox(Prefs.showStatements, 'show trust statements'),
            MyCheckbox(Prefs.skipLgtm, '''Skip statement reviews'''),
            MyCheckbox(Prefs.skipVerify, '''Skip verifying signatures (goes quicker;)'''),
            MyCheckbox(Prefs.postSignin, '''(requires new phone version) HTTP Post sign in'''),
            // MyCheckbox(Prefs.showDevMenu, 'show DEV menu'),
          ],
          child: const Row(
            children: [
              Icon(Icons.settings),
              iconSpacer,
              Text('Settings'),
            ],
          )),

      NotificationsMenu(key: UniqueKey()), // just guessing with UniqueKey()

      SubmenuButton(menuChildren: <Widget>[
        MenuItemButton(
            onPressed: () async {
              String link = generateLink();
              // DEFER: copy floater
              await alert(
                  'Nerd\'ster link',
                  '''Link for sharing or embedding with this app's current settings (one-of-us.net center, sort, type, etc...):
$link''',
                  ['Okay'],
                  context);
            },
            child: const Text('Generate link for current view..')),
        MenuItemButton(
            child: const Text('Tokenize'),
            onPressed: () async {
              (String, String)? tokenNpp = (await Tokenize.make(context));
              if (b(tokenNpp)) {
                await alert(
                    'formatted, hashed',
                    '''token (sha1 hash of formatted JSON):
${tokenNpp!.$1}

formatted JSON:
${tokenNpp.$2}''',
                    ['okay'],
                    context);
              }
            }),
        MenuItemButton(
            onPressed: () async {
              await About.show(context);
            },
            child: const Text('About')),
      ], child: const Text('/etc')),


      // Dev
      if (Prefs.showDevMenu.value)
        SubmenuButton(menuChildren: <Widget>[
          MenuItemButton(onPressed: () => dumpDump(context), child: const Text('Dump JSON state')),
          MenuItemButton(
              child: const Text('Load JSON statements'),
              onPressed: () async {
                await loadDumpDialog(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('done')));
              }),
          SubmenuButton(menuChildren: <Widget>[
            ...demos,
          ], child: const Text('Load demo')),
          SubmenuButton(menuChildren: <Widget>[
            ...demoSignins,
          ], child: const Text('Demo sign-in')),
          MenuItemButton(
              child: const Text('dump all statements'),
              onPressed: () async {
                await DumpAllStatements.show(context);
              }),
          MenuItemButton(
              child: const Text('Fetcher crash in... 3'),
              onPressed: () {
                Fetcher.testingCrashIn = 3;
              }),
        ], child: const Text('Dev')),
      // CONSIDER: const MenuTitle(['nerd', 'ster', '.', 'org'])
    ];
  }

  Menus._();
}
