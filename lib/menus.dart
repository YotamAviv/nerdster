import 'package:flutter/material.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/demotest/cases/fetcher_integration_test.dart';
import 'package:nerdster/demotest/cases/integration_tests.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/dev/corruption_check.dart';
import 'package:nerdster/dump_all_statements.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/nerdster_link.dart';
import 'package:nerdster/net/oneofus_equiv.dart';
import 'package:nerdster/notifications_menu.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
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

class IntSettingDropdown extends StatefulWidget {
  final String label;
  final ValueNotifier<int> setting;
  final List<int> values;
  const IntSettingDropdown(this.label, this.setting, this.values, {super.key});

  @override
  State<StatefulWidget> createState() => _IntSettingDropdownState();
}

class _IntSettingDropdownState extends State<IntSettingDropdown> {
  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      alignment: AlignmentDirectional.centerEnd,
      isExpanded: true,
      value: widget.setting.value,
      onChanged: (int? val) {
        progress.make(() {
          setState(() {
            widget.setting.value = val!;
          });
        }, context);
      },
      items: List.of(widget.values
          .map((i) => DropdownMenuItem<int>(value: i, child: Text('$i ${widget.label}')))),
    );
  }
}

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
            MyCheckbox(Prefs.skipLgtm, '''skip statement reviews'''),
            MyCheckbox(Prefs.censor, '''hide content censored by my network'''),
            MyCheckbox(Prefs.hideDismissed, '''hide content where network #(dis) > #(recommend)'''),
            SubmenuButton(menuChildren: <Widget>[
              IntSettingDropdown(
                  'degrees', Prefs.oneofusNetDegrees, List<int>.generate(6, (i) => i + 1)),
              IntSettingDropdown(
                  'paths', Prefs.oneofusNetPaths, List<int>.generate(2, (i) => i + 1)),
            ], child: const Text('one-of-us.net network')),
            SubmenuButton(menuChildren: <Widget>[
              IntSettingDropdown(
                  'degrees', Prefs.followNetDegrees, List<int>.generate(6, (i) => i + 1)),
              IntSettingDropdown(
                  'paths', Prefs.followNetPaths, List<int>.generate(2, (i) => i + 1)),
            ], child: const Text('follow network')),
            const Text('--------- nerdier ---------'),
            MyCheckbox(Prefs.keyLabel, 'translate gibberish'),
            MyCheckbox(Prefs.showJson, 'show JSON'),
            MyCheckbox(Prefs.showKeys, 'show equivalent keys'),
            MyCheckbox(Prefs.showStatements, 'show trust statements'),
            const Text('--------- nerdiest ---------'),
            MyCheckbox(Prefs.skipVerify, 'skip actually verifying (goes quicker)'),
            MyCheckbox(Prefs.cloudFetchDistinct, 'cloud fetch distinct (goes quicker)'),
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
            child: const Text('Tokenize/Verify..'),
            onPressed: () {
              Tokenize.startTokenize(context);
            }),
      ], child: const Text('/etc')),

      SubmenuButton(menuChildren: <Widget>[
        MenuItemButton(
            onPressed: () async {
              await About.show(context);
            },
            child: const Text('About')),
      ], child: const Text('?')),

      // Dev
      if (Prefs.dev.value)
        SubmenuButton(menuChildren: [
          MenuItemButton(
              onPressed: () {
                Jsonish.wipeCache();
                BarRefresh.refresh(context);
              },
              child: const Text('Refresh. Jsonish cache, too')),
          SubmenuButton(menuChildren: [
            MenuItemButton(onPressed: () => fetcherIntegrationTest(), child: const Text('Fetcher')),
            MenuItemButton(onPressed: () => integrationTests(), child: const Text('misc  demos')),
          ], child: const Text('integration tests')),
          MenuItemButton(onPressed: () => Comp.dumpComps(), child: const Text('compDump')),
          // MenuItemButton(onPressed: () => Fix.fix(), child: const Text('Fix')),
          MenuItemButton(
              onPressed: () => CorruptionCheck.make(), child: const Text('CorruptionCheck')),
          SubmenuButton(menuChildren: <Widget>[
            ...demos,
          ], child: const Text('run case')),
          MenuItemButton(onPressed: () => dumpDump(context), child: const Text('Dump JSON state')),
          MenuItemButton(
              child: const Text('Load JSON statements'),
              onPressed: () async {
                await loadDumpDialog(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('done')));
              }),
          SubmenuButton(menuChildren: <Widget>[
            ...demoSignins,
          ], child: const Text('Demo sign-in')),
          MenuItemButton(
              child: const Text('dump all statements'),
              onPressed: () async {
                await DumpAllStatements.show(context);
              }),
        ], child: const Text('DEV')),
      // CONSIDER: const MenuTitle(['nerd', 'ster', '.', 'org'])
    ];
  }

  Menus._();
}
