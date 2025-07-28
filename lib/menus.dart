import 'package:flutter/material.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/dev/just_sign.dart';
import 'package:nerdster/verify.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/fetcher_integration_test.dart';
import 'package:nerdster/demotest/cases/integration_tests.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/dev/corruption_check.dart';
import 'package:nerdster/dump_all_statements.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/nerdster_link.dart';
import 'package:nerdster/notifications_menu.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/sign_in.dart';
import 'package:nerdster/sign_in_menu.dart';
import 'package:nerdster/singletons.dart';

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
        progress.make(() async {
          setState(() {
            widget.setting.value = val!;
          });
          await Comp.waitOnComps([keyLabels, contentBase]);
        }, context);
      },
      items: List.of(widget.values
          .map((i) => DropdownMenuItem<int>(value: i, child: Text('$i ${widget.label}')))),
    );
  }
}

class Menus {
  static List<Widget> build(BuildContext context) {
    List<Widget> demos = <Widget>[];
    for (final e in DemoKey.demos.entries) {
      String name = e.key;
      demos.add(MenuItemButton(
          onPressed: () async {
            demo = name;
            DemoKey.clear();
            DemoKey oneofus;
            DemoKey? delegate;
            (oneofus, delegate) = await e.value();
            await signInState.signIn(oneofus.token, delegate?.keyPair, context: context);
          },
          child: Text(name)));
    }

    return <Widget>[
      SignInMenu(),

      // Settings
      SubmenuButton(
          menuChildren: [
            // Cleaning up the UI, removing much..
            // MyCheckbox(Prefs.censor, '''hide content censored by my network'''),
            // MyCheckbox(Prefs.hideDisliked, '''hide content where network sum(like) < 0'''),
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
            MyCheckbox(Prefs.skipLgtm, '''skip statement reviews'''),
            // const Text('--------- nerdier ---------'),
            // MyCheckbox(Prefs.keyLabel, 'translate gibberish'),
            MyCheckbox(Prefs.showStuff, 'show JSON, keys, and statements'),
            // MyCheckbox(Prefs.showJson, 'show JSON'),
            // MyCheckbox(Prefs.showKeys, 'show equivalent keys'),
            // MyCheckbox(Prefs.showStatements, 'show trust statements'),
          ],
          child: const Row(
            children: [
              Icon(Icons.settings),
              iconSpacer,
              Text('Settings'),
            ],
          )),

      NotificationsMenu(),

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
            child: const Text('Generate link for current view...')),
        MenuItemButton(
            child: const Text(kVerify),
            onPressed: () async {
              await showDialog(
                  context: context,
                  builder: (context) => Dialog(
                      // Doesn't work: shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
                      child: Navigator(onGenerateRoute: (settings) {
                        return MaterialPageRoute(builder: (_) => Verify());
                      })));
            }),
          MenuItemButton(
              onPressed: () => JustSign.sign(context),
              child: const Text('Just sign...')),
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
              onPressed: () => pasteSignin(context),
              child: const Row(children: [Icon(Icons.copy), iconSpacer, Text('paste sign-in')])),
          MenuItemButton(
              onPressed: () => showTopRightDialog(
                  context,
                  CredentialsWidget(
                      signInState.centerResetJson, signInState.signedInDelegatePublicKeyJson)),
              child: Text('showCredentials')),

          SubmenuButton(menuChildren: [
            MyCheckbox(Prefs.cloudFunctionsFetch, 'cloudFunctionsFetch (goes quicker)'),
            MyCheckbox(Prefs.batchFetch, 'batchFetch'),
            MyCheckbox(Prefs.streamBatchFetch, 'streamBatchFetch'),
            MyCheckbox(Prefs.fetchRecent, '''fetchRecent'''),
            MyCheckbox(Prefs.slowFetch, '''slowFetch'''),
            MyCheckbox(Prefs.skipVerify, 'skip actually verifying (goes quicker)'),
          ], child: const Text('cloud fetching')),

          MenuItemButton(
              onPressed: () {
                // Workaround for omit=["I"] when fetching statements. We have to know our own key
                // to get going.
                Json centerJson = Jsonish.find(signInState.center!)!.json;
                Jsonish.wipeCache();
                Jsonish(centerJson);
                BarRefresh.refresh(context);
              },
              child: const Text('Refresh. Jsonish cache, too')),
          SubmenuButton(menuChildren: [
            MenuItemButton(onPressed: fetcherIntegrationTest, child: const Text('Fetcher')),
            MenuItemButton(onPressed: integrationTests, child: const Text('misc demos')),
            MenuItemButton(
                onPressed: () {
                  fetcherIntegrationTest();
                  integrationTests();
                },
                child: const Text('all')),
          ], child: const Text('integration tests')),
          SubmenuButton(menuChildren: [
            MenuItemButton(
                onPressed: () => DemoKey.showDemoCredentials(context),
                child: const Text('show all demo credentials')),
            ...demos
          ], child: const Text('demo')),
          MenuItemButton(onPressed: () => Comp.dumpComps(), child: const Text('compDump')),
          // MenuItemButton(onPressed: () => Fix.fix(), child: const Text('Fix')),
          MenuItemButton(
              onPressed: () => CorruptionCheck.make(), child: const Text('CorruptionCheck')),
          MenuItemButton(onPressed: () => dumpDump(context), child: const Text('Dump JSON state')),
          MenuItemButton(
              child: const Text('Load JSON statements'),
              onPressed: () async {
                await loadDumpDialog(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('done')));
              }),
          MenuItemButton(
              onPressed: () async {
                String oneofus = signInState.centerReset!;
                var credentials = {
                  kOneofusDomain: Jsonish.find(oneofus)!.json,
                  if (b(signInState.signedInDelegateKeyPair))
                    kNerdsterDomain: await signInState.signedInDelegateKeyPair!.json,
                };
                print(oneofus);
                print(Jsonish.encoder.convert(credentials));
              },
              child: const Text('dump signed-in credentials')),
          MenuItemButton(
              child: const Text('dump all statements'),
              onPressed: () async {
                await DumpAllStatements.show(context);
              }),
          MenuItemButton(
              child: const Text('MediaQuery.of(context).size'),
              onPressed: () =>
                  alert(MediaQuery.of(context).size.toString(), '', ['okay'], context)),
        ], child: const Text('DEV')),
      // CONSIDER: const MenuTitle(['nerd', 'ster', '.', 'org'])
    ];
  }

  Menus._();
}
