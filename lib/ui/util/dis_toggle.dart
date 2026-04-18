import 'package:flutter/material.dart';

/// 3-way toggle: null → 'snooze' → 'forever' → null.
/// Used in content_card (large UI) and wherever a dis toggle is needed.
class DisToggle extends StatelessWidget {
  final ValueNotifier<String?> notifier;
  final VoidCallback? callback;

  const DisToggle({
    super.key,
    required this.notifier,
    this.callback,
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
          color = null;
          tooltip = 'Dismiss';
        }

        return Tooltip(
          message: tooltip,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(icon),
                color: color,
                onPressed: () {
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
