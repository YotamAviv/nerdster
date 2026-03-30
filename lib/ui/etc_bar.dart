import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/dev/just_sign.dart';
import 'package:nerdster/nerdster_link.dart';
import 'package:nerdster/verify.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/ui/util/my_checkbox.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:share_plus/share_plus.dart';

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
                        final String link = generateLink();
                        if (kIsWeb) {
                          _showWebShareDialog(context, link);
                        } else {
                          await Share.share(link, subject: 'Nerdster view link');
                        }
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

                  // Show Crypto
                  ValueListenableBuilder<bool>(
                    valueListenable: Setting.get<bool>(SettingType.showCrypto).notifier,
                    builder: (context, showCrypto, _) {
                      return MyCheckbox(
                          Setting.get<bool>(SettingType.showCrypto).notifier, 'Show Crypto',
                          alwaysShowTitle: true);
                    },
                  ),

                  // FYI
                  ValueListenableBuilder<bool>(
                    valueListenable: Setting.get<bool>(SettingType.lgtm).notifier,
                    builder: (context, val, _) {
                      return MyCheckbox(Setting.get<bool>(SettingType.lgtm).notifier, 'Show FYI',
                          alwaysShowTitle: true);
                    },
                  ),

                  // Just Sign
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.border_color),
                    child: Text('Just Sign'),
                    onPressed: () => JustSign.sign(context),
                  ),
                  // Verify
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.verified_user),
                    child: Text('Just Verify'),
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

void _showWebShareDialog(BuildContext context, String link) {
  showDialog(
    context: context,
    builder: (ctx) {
      bool copied = false;
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.link, size: 20),
              SizedBox(width: 8),
              Text('Share link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share with your current settings (PoV, tags, sort, etc.):',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey.shade50,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: SelectableText(
                  link,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  maxLines: 4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              icon: Icon(copied ? Icons.check : Icons.copy, size: 16),
              label: Text(copied ? 'Copied!' : 'Copy link'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                setState(() => copied = true);
              },
            ),
          ],
        );
      });
    },
  );
}
