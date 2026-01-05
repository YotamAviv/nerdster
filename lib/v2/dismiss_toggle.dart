import 'package:flutter/material.dart';
import 'package:nerdster/util_ui.dart';
import 'package:nerdster/app.dart';

class DismissToggle extends StatelessWidget {
  final ValueNotifier<String?> notifier;
  final bool disabled;
  final VoidCallback? callback;

  const DismissToggle({
    required this.notifier,
    this.disabled = false,
    this.callback,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: notifier,
      builder: (context, value, _) {
        IconData icon;
        Color? color;
        String tooltip;

        if (value == 'snooze') {
          icon = Icons.snooze;
          color = Colors.brown;
          tooltip = 'Snoozed (hidden until new activity)';
        } else if (value == 'forever') {
          icon = Icons.swipe_left;
          color = Colors.brown;
          tooltip = 'Dismissed forever';
        } else {
          icon = Icons.swipe_left_outlined;
          color = null; // Default icon color (usually grey/black)
          tooltip = 'Dismiss';
        }

        TextStyle? textStyle = disabled ? hintStyle : null;

        return Tooltip(
          message: tooltip,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSmall.value) Text('Dismiss', style: textStyle),
              IconButton(
                icon: Icon(icon),
                color: color,
                onPressed: disabled
                    ? null
                    : () {
                        if (value == null) {
                          notifier.value = 'snooze';
                        } else if (value == 'snooze') {
                          notifier.value = 'forever';
                        } else {
                          notifier.value = null;
                        }
                        callback?.call();
                      },
              ),
            ],
          ),
        );
      },
    );
  }
}
