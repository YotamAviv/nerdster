import 'package:flutter/material.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/dev/just_sign.dart';
import 'package:nerdster/nerdster_link.dart';
import 'package:nerdster/ui/util/alert.dart'; // For alert dialog
import 'package:nerdster/verify.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/logic/feed_controller.dart'; // Add

class EtcBar extends StatelessWidget {
  final Widget notifications;
  final FeedController controller; // Add

  const EtcBar({super.key, required this.notifications, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Notifications
                  MenuBar(
                    style: const MenuStyle(
                      elevation: WidgetStatePropertyAll(0),
                      backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                      padding: WidgetStatePropertyAll(EdgeInsets.zero), // Minimize padding
                    ),
                    children: [notifications],
                  ),
                  const SizedBox(width: 8),

                  // Share
                  Tooltip(
                    message: 'Share this view',
                    child: IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () async {
                        String link = generateLink();
                        await alert(
                            'Nerd\'ster link',
                            '''Share, bookmark, or embed with your current settings (PoV, follow context, tags, sort, type, etc...):
$link''',
                            ['Okay'],
                            context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Refresh
          Tooltip(
            message: 'Refresh the feed',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => controller.refresh(),
            ),
          ),
          const SizedBox(width: 8),

          // /etc Menu
          MenuBar(
            style: const MenuStyle(
              elevation: WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
              padding: WidgetStatePropertyAll(EdgeInsets.zero),
            ),
            children: [
              SubmenuButton(
                menuChildren: [
                  // Verify
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.verified_user),
                    child: const Text('Verify'),
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: Navigator(
                            onGenerateRoute: (settings) {
                              return MaterialPageRoute(builder: (_) => Verify());
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  // Just Sign
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.border_color),
                    child: const Text('Sign'),
                    onPressed: () => JustSign.sign(context),
                  ),
                  // Show Crypto
                  ValueListenableBuilder<bool>(
                    valueListenable: Setting.get<bool>(SettingType.showCrypto).notifier,
                    builder: (context, showCrypto, _) {
                      return MenuItemButton(
                        leadingIcon: Icon(showCrypto ? Icons.key : Icons.key_off,
                            color: showCrypto ? Theme.of(context).primaryColor : null),
                        closeOnActivate: false,
                        onPressed: () =>
                            Setting.get<bool>(SettingType.showCrypto).value = !showCrypto,
                        child: Text('Show Crypto details',
                            style: TextStyle(
                                fontWeight: showCrypto ? FontWeight.bold : FontWeight.normal)),
                      );
                    },
                  ),
                  // Identity Network Confidence
                  ValueListenableBuilder<String>(
                    valueListenable: Setting.get<String>(SettingType.identityPathsReq).notifier,
                    builder: (context, current, _) {
                      IconData shieldIcon = Icons.shield_outlined;
                      Color? shieldColor;
                      switch (current) {
                        case 'permissive':
                          shieldIcon = Icons.shield_outlined;
                          shieldColor = Colors.green;
                          break;
                        case 'standard':
                          shieldIcon = Icons.shield_sharp;
                          shieldColor = Colors.blue;
                          break;
                        case 'strict':
                          shieldIcon = Icons.security;
                          shieldColor = Colors.red;
                          break;
                      }

                      return SubmenuButton(
                        menuChildren: ['permissive', 'standard', 'strict'].map((val) {
                          return MenuItemButton(
                            closeOnActivate: false,
                            onPressed: () =>
                                Setting.get<String>(SettingType.identityPathsReq).value = val,
                            trailingIcon: current == val ? const Icon(Icons.check) : null,
                            child: Text(val),
                          );
                        }).toList(),
                        child: Row(
                          children: [
                            Icon(shieldIcon, color: shieldColor),
                            const SizedBox(width: 8),
                            Text(current),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                child: const Text('/etc'),
              )
            ],
          ),
          const SizedBox(width: 8),

          // About (Nerdster Logo)
          Tooltip(
            message: 'About Nerdster',
            child: InkWell(
              onTap: () => About.show(context),
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Image.asset(
                  'assets/images/nerd.png',
                  height: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
