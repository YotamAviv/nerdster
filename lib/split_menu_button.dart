import 'package:flutter/material.dart';
import 'package:nerdster/menus.dart';

/// ChatGPT

class SplitMenuButton extends StatelessWidget {
  final Widget? icon;
  final String label;
  final VoidCallback? onPrimary;
  final List<Widget> menuChildren;

  const SplitMenuButton(
      {super.key,
      required this.label,
      required this.onPrimary,
      required this.menuChildren,
      this.icon});

  bool get enabled => onPrimary != null;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) {
        return Material(
            color: Colors.transparent,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                  onTap: enabled ? onPrimary : null,
                  customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (icon != null) ...[icon!, iconSpacer],
                        Text(label),
                      ]))),
              InkWell(
                  onTap: enabled
                      ? () => controller.isOpen ? controller.close() : controller.open()
                      : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    child: Icon(Icons.arrow_drop_down),
                  ))
            ]));
      },
      // Provide the menu items here
      menuChildren: menuChildren,
    );
  }
}
