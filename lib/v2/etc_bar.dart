import 'package:flutter/material.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/dev/just_sign.dart';
import 'package:nerdster/nerdster_link.dart';
import 'package:nerdster/oneofus/ui/alert.dart'; // For alert dialog
import 'package:nerdster/verify.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
// v2/refresh_signal.dart import removed via editing
import 'package:nerdster/v2/feed_controller.dart'; // Add

class EtcBar extends StatelessWidget {
  final Widget notifications;
  final V2FeedController controller; // Add

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
                  Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 12.0),
                        child: Icon(Icons.key),
                      ),
                      MyCheckbox(Setting.get<bool>(SettingType.showCrypto).notifier,
                          'Show Crypto (JSON, keys, and statements)'),
                    ],
                  ),
                  // Identity Network Confidence
                  SubmenuButton(
                    menuChildren: ['permissive', 'standard', 'strict'].map((val) {
                      return ValueListenableBuilder<String>(
                        valueListenable:
                            Setting.get<String>(SettingType.identityPathsReq).notifier,
                        builder: (context, current, _) {
                          return MenuItemButton(
                            onPressed: () =>
                                Setting.get<String>(SettingType.identityPathsReq).value = val,
                            trailingIcon: current == val ? const Icon(Icons.check) : null,
                            child: Text(val),
                          );
                        },
                      );
                    }).toList(),
                    child: const Text('Identity Network Confidence'),
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
