import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demo_setup.dart';
import 'package:nerdster/demotest/cases/integration_tests.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/dev/corruption_check.dart';
import 'package:nerdster/dev/just_sign.dart';
import 'package:nerdster/dump_all_statements.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/nerdster_link.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/sign_in_menu.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/verify.dart';

const iconSpacer = SizedBox(width: 3);

class Menus {
  static List<Widget> build(
    BuildContext context, {
    required Widget v2Notifications,
  }) {
    List<Widget> demos = <Widget>[];
    for (final e in DemoKey.demos.entries) {
      String name = e.key;
      demos.add(MenuItemButton(
          onPressed: () async {
            demo = name;
            DemoKey.reset();
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
            await signInState.signIn(oneofus.token, delegate?.keyPair);
          },
          child: Text(name)));
    }

    return <Widget>[
      // Sign in
      SignInMenu(),

      // Settings
      SubmenuButton(menuChildren: [
        MyCheckbox(Setting.get<bool>(SettingType.censor).notifier,
            '''Hide content censored by my network'''),
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
      v2Notifications,

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
          SubmenuButton(menuChildren: [
            MyCheckbox(Setting.get<bool>(SettingType.skipVerify).notifier,
                'skip actually verifying (goes quicker)'),
          ], child: const Text('cloud fetching')),
          MenuItemButton(
              onPressed: () {
                Json povJson = Jsonish.find(signInState.pov)!.json;
                Jsonish.wipeCache();
                Jsonish(povJson);
              },
              child: const Text('Refresh Jsonish cache')),
          SubmenuButton(menuChildren: [
            MenuItemButton(onPressed: integrationTests, child: const Text('misc demos')),
            MenuItemButton(
                onPressed: () {
                  integrationTests();
                },
                child: const Text('all')),
          ], child: const Text('integration tests')),
          SubmenuButton(menuChildren: [], child: const Text('V2 Scenarios')),
          SubmenuButton(menuChildren: [
            MenuItemButton(
                onPressed: DemoKey.dumpDemoCredentials, child: const Text('dumpDemoCredentials')),
            ...demos
          ], child: const Text('demo')),
          MenuItemButton(onPressed: () => Comp.dumpComps(), child: const Text('compDump')),
          MenuItemButton(
              onPressed: () {
                CorruptionCheck.check(signInState.pov, kOneofusDomain);
                if (signInState.delegate != null) {
                  CorruptionCheck.check(signInState.pov, kNerdsterDomain);
                }
              },
              child: const Text('CorruptionCheck')),
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
