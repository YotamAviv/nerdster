import 'package:flutter/material.dart';
import 'package:nerdster/menus.dart';
import 'package:nerdster/v2/interpreter.dart';
import 'package:nerdster/v2/json_display.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/model.dart';

class V2NotificationsMenu extends StatelessWidget {
  final TrustGraph? trustGraph;
  final FollowNetwork? followNetwork;
  final V2Labeler labeler;

  const V2NotificationsMenu({super.key, this.trustGraph, this.followNetwork, required this.labeler});

  @override
  Widget build(BuildContext context) {
    final List<TrustNotification> allNotifications = [];
    if (trustGraph != null) {
      allNotifications.addAll(trustGraph!.notifications);
    }
    if (followNetwork != null) {
      allNotifications.addAll(followNetwork!.notifications);
    }

    List<MenuItemButton> items = [];
    for (final notification in allNotifications) {
      items.add(_buildNotificationItem(notification, context));
    }

    Color? color = items.isNotEmpty ? Colors.red : null;
    return SubmenuButton(
        menuChildren: items,
        child: Row(
          children: [
            Icon(Icons.notifications, color: color),
            iconSpacer,
            Text('Notifications (V2)', style: TextStyle(color: color)),
          ],
        ));
  }

  MenuItemButton _buildNotificationItem(TrustNotification notification, BuildContext context) {
    String reason = notification.reason;
    reason = reason.replaceAllMapped(RegExp(r'[0-9a-f]{40}'), (match) {
      return labeler.getLabel(match.group(0)!);
    });

    return MenuItemButton(
      onPressed: () {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: SelectableText(reason),
              content: _V2StatementNotification(notification, labeler: labeler),
              actions: <Widget>[
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
      child: Text(reason),
    );
  }
}

class _V2StatementNotification extends StatelessWidget {
  final TrustNotification notification;
  final V2Labeler labeler;

  const _V2StatementNotification(this.notification, {required this.labeler});

  @override
  Widget build(BuildContext context) {
    final Statement statement = notification.relatedStatement;
    final Jsonish jsonish = statement.jsonish;
    final String issuerName = labeler.getLabel(statement.iToken);
    final String subjectName = labeler.getLabel(statement.subjectToken);

    return SingleChildScrollView(
      child: ListBody(
        children: <Widget>[
          SelectableText('Issuer: $issuerName'),
          const SizedBox(height: 8),
          SelectableText('Subject: $subjectName'),
          const SizedBox(height: 8),
          if (statement.comment != null) ...[
            SelectableText('Comment: ${statement.comment}'),
            const SizedBox(height: 8),
          ],
          const Divider(),
          const SelectableText('Statement Details:'),
          V2JsonDisplay(jsonish.json, interpreter: V2Interpreter(labeler)),
          const SizedBox(height: 8),
          TextButton(
            child: const Text('View Statement JSON'),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => Dialog(
                child: JsonQrDisplay(jsonish.json),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
