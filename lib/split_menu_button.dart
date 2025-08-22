import 'package:flutter/material.dart';
import 'package:nerdster/menus.dart';

/// A split button suitable for a MenuBar: left = primary action,
/// right = dropdown chevron that opens a menu of secondary actions.

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Left: primary action
              InkWell(
                onTap: enabled ? onPrimary : null,
                customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        iconSpacer,
                        icon!,
                      ],
                      Text(label),
                    ],
                  ),
                ),
              ),

              // Right: dropdown chevron
              InkWell(
                onTap: enabled
                    ? () => controller.isOpen ? controller.close() : controller.open()
                    : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  child: Icon(Icons.arrow_drop_down),
                ),
              ),
            ],
          ),
        );
      },
      // Provide the menu items here
      menuChildren: menuChildren,
    );
  }
}
