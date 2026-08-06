import 'package:flutter/material.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/dev/just_sign.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/ui/util/my_checkbox.dart';
import 'package:nerdster/verify.dart';

/// The hamburger menu, shared by the content and graph views.
///
/// A couple of items only mean something over content. On views where they
/// don't apply they stay in place, greyed with a tooltip explaining why,
/// so the menu reads the same everywhere.
class FeedMenuButton extends StatefulWidget {
  final FeedController controller;

  /// False where content-only items (dismissed, censored) have no effect.
  final bool contentEnabled;

  const FeedMenuButton(
    this.controller, {
    super.key,
    this.contentEnabled = true,
  });

  @override
  State<FeedMenuButton> createState() => _FeedMenuButtonState();
}

class _FeedMenuButtonState extends State<FeedMenuButton> {
  static const String _contentOnly = 'Content view only';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(FeedMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// A menu item that's inert (and says so) unless we're over content.
  Widget _contentItem({
    required IconData box,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    final bool enabled = widget.contentEnabled;
    final item = MenuItemButton(
      leadingIcon: Icon(box, color: enabled ? color : Colors.grey, size: 20),
      onPressed: enabled ? onPressed : null,
      child: Text(label),
    );
    return enabled ? item : Tooltip(message: _contentOnly, child: item);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return MenuAnchor(
      builder: (context, menuController, _) => IconButton(
        icon: const Icon(Icons.menu),
        visualDensity: VisualDensity.compact,
        tooltip: 'Menu',
        onPressed: () => menuController.isOpen
            ? menuController.close()
            : menuController.open(),
      ),
      menuChildren: [
        _contentItem(
          box: controller.filterMode == DisFilterMode.my
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          color: Colors.brown,
          label: 'Hide dismissed',
          onPressed: () => controller.filterMode =
              controller.filterMode == DisFilterMode.my
                  ? DisFilterMode.ignore
                  : DisFilterMode.my,
        ),
        _contentItem(
          box: controller.enableCensorship
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          color: Colors.red,
          label: 'Filter censored',
          onPressed: () =>
              controller.enableCensorship = !controller.enableCensorship,
        ),
        const Divider(),
        ValueListenableBuilder<String>(
          valueListenable:
              Setting.get<String>(SettingType.identityPathsReq).notifier,
          builder: (context, current, _) {
            final (IconData icon, Color color) = switch (current) {
              'permissive' => (Icons.shield_outlined, Colors.green),
              'strict' => (Icons.security, Colors.red),
              _ => (Icons.shield_sharp, Colors.blue),
            };
            return SubmenuButton(
              menuChildren: ['permissive', 'standard', 'strict'].map((val) {
                return MenuItemButton(
                  closeOnActivate: false,
                  onPressed: () =>
                      Setting.get<String>(SettingType.identityPathsReq).value =
                          val,
                  trailingIcon: current == val ? const Icon(Icons.check) : null,
                  child: Text(val),
                );
              }).toList(),
              child: Row(children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                const Text('Identity bar'),
              ]),
            );
          },
        ),
        const Divider(),
        MyCheckbox(Setting.get<bool>(SettingType.showCrypto).notifier,
            'Show Crypto',
            alwaysShowTitle: true),
        MyCheckbox(Setting.get<bool>(SettingType.lgtm).notifier, 'Show FYI',
            alwaysShowTitle: true),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.border_color),
          child: const Text('Just Sign'),
          onPressed: () => JustSign.sign(context),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.verified_user),
          child: const Text('Just Verify'),
          onPressed: () async {
            await showDialog(
              context: context,
              builder: (context) => Dialog(
                child: Navigator(
                  onGenerateRoute: (settings) =>
                      MaterialPageRoute(builder: (_) => Verify()),
                ),
              ),
            );
          },
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: SizedBox(
            width: 20,
            height: 20,
            child: Image.asset('assets/images/nerd.png'),
          ),
          child: const Text('About'),
          onPressed: () => About.show(context),
        ),
        if (Setting.get<bool>(SettingType.dev).value) ...[
          const Divider(),
          MenuItemButton(
            leadingIcon: const Icon(Icons.timer_outlined),
            child: const Text('Benchmark seeding'),
            onPressed: () => controller.runBenchmark(context),
          ),
        ],
      ],
    );
  }
}

/// The refresh button, sitting just left of the menu on every view.
class FeedRefreshButton extends StatelessWidget {
  final FeedController controller;

  const FeedRefreshButton(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Refresh',
      child: IconButton(
        icon: const Icon(Icons.refresh, color: Colors.blue),
        visualDensity: VisualDensity.compact,
        onPressed: () => controller.refresh(),
      ),
    );
  }
}
