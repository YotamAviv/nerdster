import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/demotest/cases/fetcher_integration_test.dart';
import 'package:nerdster/demotest/cases/integration_tests.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/dev/corruption_check.dart';
import 'package:nerdster/dev/just_sign.dart';
import 'package:nerdster/dump_all_statements.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/nerdster_link.dart';
import 'package:nerdster/notifications_menu.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/sign_in_menu.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/verify.dart';

const iconSpacer = SizedBox(width: 3);

class IntSettingDropdown extends StatefulWidget {
  final String label;
  final ValueNotifier<int> setting;
  final List<int> values;
  const IntSettingDropdown(this.label, this.setting, this.values, {super.key});

  @override
  State<StatefulWidget> createState() => _IntSettingDropdownState();
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
            if (DemoKey.getExports().isNotEmpty) {
                String exportDataJs = DemoKey.getExportsString();
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                      title: const Text('Demo Data'),
                      content: SingleChildScrollView(child: SelectableText(exportDataJs)),
                      actions: [
                      TextButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: exportDataJs));
                          if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard')));
                          }
                        },
                        child: const Text('Copy')),
                      TextButton(
                        onPressed: () => Navigator.pop(context), child: const Text('Close'))
                      ]));
            }
            await signInState.signIn(oneofus.token, delegate?.keyPair, context: context);
          },
          child: Text(name)));
    }

    return <Widget>[
      // Sign in
      SignInMenu(),

      // Settings
      SubmenuButton(menuChildren: [
        // Cleaning up the UI, removing much..
        // MyCheckbox(Prefs.censor, '''hide content censored by my network'''),
        SubmenuButton(menuChildren: <Widget>[
          IntSettingDropdown('Degrees', Setting.get<int>(SettingType.identityNetDegrees).notifier,
              List<int>.generate(6, (i) => i + 1)),
          IntSettingDropdown('Paths', Setting.get<int>(SettingType.identityNetPaths).notifier,
              List<int>.generate(2, (i) => i + 1)),
        ], child: const Text('Identity network')),
        SubmenuButton(menuChildren: <Widget>[
          IntSettingDropdown('Degrees', Setting.get<int>(SettingType.followNetDegrees).notifier,
              List<int>.generate(6, (i) => i + 1)),
          IntSettingDropdown('Paths', Setting.get<int>(SettingType.followNetPaths).notifier,
              List<int>.generate(2, (i) => i + 1)),
        ], child: const Text('Follow network')),
        // const Text('--------- nerdier ---------'),
        SubmenuButton(menuChildren: [
          MyCheckbox(Setting.get<bool>(SettingType.skipCredentials).notifier,
              'Sign-in credentials received',
              opposite: true),
          MyCheckbox(
              Setting.get<bool>(SettingType.skipLgtm).notifier, 'Statements review/confirmation',
              opposite: true),
          MyCheckbox(Setting.get<bool>(SettingType.showCrypto).notifier,
              'Crypto (JSON, keys, and statements)'),
        ], child: const Text("Show/don't show")),
      ], child: const Row(children: [Icon(Icons.settings), iconSpacer, Text('Settings')])),

      // Notifications
      NotificationsMenu(),

      // Share
      SubmenuButton(menuChildren: <Widget>[
        MenuItemButton(
            onPressed: () async {
              String link = generateLink();
              // DEFER: copy floater
              await alert(
                  'Nerd\'ster link',
                  '''Share, bookmark, or embed with your current settings (PoV, follow context, tags, sort, type, etc...):
$link''',
                  ['Okay'],
                  context);
            },
            child: const Text('Generate link for this view...')),
      ], child: const Row(children: [Icon(Icons.share), iconSpacer, Text('Share')])),

      // /etc
      SubmenuButton(menuChildren: <Widget>[
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
        MenuItemButton(onPressed: () => JustSign.sign(context), child: const Text('Just sign...')),
      ], child: const Text('/etc')),

      // ?
      SubmenuButton(menuChildren: <Widget>[
        MenuItemButton(
            onPressed: () async {
              await About.show(context);
            },
            child: const Text('About')),
      ], child: const Row(children: [Icon(Icons.help)])),

      // Dev
      if (Setting.get<bool>(SettingType.dev).value)
        SubmenuButton(menuChildren: [
          MyCheckbox(Setting.get<bool>(SettingType.bogus).notifier, 'bogus'),

          SubmenuButton(menuChildren: [
            MyCheckbox(Setting.get<bool>(SettingType.httpFetch).notifier, 'httpFetch'),
            MyCheckbox(Setting.get<bool>(SettingType.batchFetch).notifier, 'batchFetch'),
            MyCheckbox(Setting.get<bool>(SettingType.skipVerify).notifier,
                'skip actually verifying (goes quicker)'),
          ], child: const Text('cloud fetching')),

          MenuItemButton(
              onPressed: () {
                // Workaround for omit=["I"] when fetching statements. We have to know our own key
                // to get going.
                Json centerJson = Jsonish.find(signInState.pov!)!.json;
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
                onPressed: DemoKey.dumpDemoCredentials, child: const Text('dumpDemoCredentials')),
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
