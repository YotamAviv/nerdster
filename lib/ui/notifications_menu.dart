import 'package:float_column/float_column.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/logic/interpreter.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/ui/graph_view.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/ui/json_display.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsMenu extends StatelessWidget {
  final TrustGraph? trustGraph;
  final FollowNetwork? followNetwork;
  final DelegateResolver? delegateResolver;
  final Labeler labeler;
  final FeedController controller;
  final List<SourceError> sourceErrors;
  final List<SystemNotification> systemNotifications;

  const NotificationsMenu({
    super.key,
    this.trustGraph,
    this.followNetwork,
    this.delegateResolver,
    required this.labeler,
    required this.controller,
    this.sourceErrors = const [],
    this.systemNotifications = const [],
  });

  static bool shouldShow(FeedModel? model) {
    if (model == null) return false;

    return model.sourceErrors.isNotEmpty ||
        model.trustGraph.notifications.isNotEmpty ||
        model.followNetwork.notifications.isNotEmpty ||
        model.delegateResolver.notifications.isNotEmpty ||
        model.systemNotifications.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final List<TrustNotification> allNotifications = [];
    if (trustGraph != null) {
      allNotifications.addAll(trustGraph!.notifications);
    }
    if (followNetwork != null) {
      allNotifications.addAll(followNetwork!.notifications);
    }
    if (delegateResolver != null) {
      allNotifications.addAll(delegateResolver!.notifications);
    }

    List<MenuItemButton> items = [];

    // Source Errors (Corruption)
    for (final error in sourceErrors) {
      items.add(MenuItemButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Data Corruption Error'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Token: ${labeler.getLabel(error.token ?? "Unknown")}'),
                    const SizedBox(height: 8),
                    Text('Message: ${error.reason}'),
                    if (error.originalError != null) ...[
                      const SizedBox(height: 8),
                      const Text('Original Error:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(error.originalError.toString()),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'All statements for this key have been discarded.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Corruption: ${labeler.getLabel(error.token ?? "Unknown")}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ));
    }

    // System Notifications (Invisible, Delegate issues, etc)
    for (final notification in systemNotifications) {
      items.add(MenuItemButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(notification.title),
              content: Text(notification.description),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Row(
            children: [
              Text(notification.isError ? '⛔' : '⚠️'),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                          color: notification.isError ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      notification.description,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
    }

    for (final notification in allNotifications) {
      items.add(_buildNotificationItem(notification, context));
    }

    if (items.isEmpty) {
      debugPrint('NotificationsMenu: items is empty but shouldShow was likely true.');
      debugPrint('counts: sys=${systemNotifications.length} err=${sourceErrors.length} '
          'trust=${trustGraph?.notifications.length} follow=${followNetwork?.notifications.length}');
      return const SizedBox.shrink();
    }

    Color? color = Colors.red;
    return SubmenuButton(
        menuChildren: items,
        child: Row(
          children: [
            Icon(Icons.notifications, color: color),
          ],
        ));
  }

  MenuItemButton _buildNotificationItem(TrustNotification notification, BuildContext context) {
    String reason = notification.reason;
    reason = reason.replaceAllMapped(RegExp(r'[0-9a-f]{40}'), (match) {
      return labeler.getLabel(match.group(0)!);
    });

    final isConflict = notification.isConflict;
    final icon = isConflict ? Icons.error_outline : Icons.warning_amber_rounded;
    final color = isConflict ? Colors.red : Colors.orange;

    return MenuItemButton(
      onPressed: () {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: SelectableText(reason),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: _StatementNotification(notification,
                    labeler: labeler,
                    trustGraph: trustGraph,
                    followNetwork: followNetwork,
                    controller: controller),
              ),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                reason,
                style: TextStyle(color: color),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _StatementNotification extends StatelessWidget {
  final TrustNotification notification;
  final Labeler labeler;
  final TrustGraph? trustGraph;
  final FollowNetwork? followNetwork;
  final FeedController controller;

  const _StatementNotification(this.notification,
      {required this.labeler,
      this.trustGraph,
      this.followNetwork,
      required this.controller});

  @override
  Widget build(BuildContext context) {
    final Statement statement = notification.rejectedStatement;
    final Jsonish jsonish = statement.jsonish;

    return SingleChildScrollView(
      child: SelectionArea(
        child: FloatColumn(
          children: [
            Floatable(
              float: FCFloat.end,
              clear: FCClear.none,
              padding: const EdgeInsets.only(left: 16, bottom: 16),
              child: SizedBox(
                width: 350,
                height: 350,
                child: Card(
                  elevation: 2,
                  color: Colors.grey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      child: JsonDisplay(jsonish.json, interpreter: NerdsterInterpreter(labeler)),
                    ),
                  ),
                ),
              ),
            ),
            WrappableText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, height: 1.4),
                children: [
                  const TextSpan(
                      text:
                          '''A conflict was encountered during the trust network computation when processing the statement displayed to the right:

This doesn't necessarily require you to do anything. For example if a key you indirectly trust is blocked by another key that you indirectly trust, then it should matter to you, and you'll see a notification. But when the owner of the key that's being blocked signs in, he'll see a notification, too, and sorting this out should be more on him than on you.
That said, even in that situation, it may be the case that that guy never checks his notifications, and so maybe pick up the slack for him.

Tactics for addressing this:
- If you think you know the individuals involved, get in touch with them, figure it out, and get it straightened out by clearing trusts or blocks or stating new ones.
- Try browsing as others (different PoV). You'll see the notifications they would see, and this may shed light on the situation.
- Email '''),
                  TextSpan(
                    text: 'conflict-help@nerdster.org',
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(Uri.parse('mailto:conflict-help@nerdster.org'));
                      },
                  ),
                  const TextSpan(
                      text:
                          '''. Include the link from the "menu => Share => Generate link for this view".

'''),
                  WidgetSpan(
                    child: Wrap(
                      spacing: 8.0,
                      children: [
                        ElevatedButton(
                          onPressed: () => _showGraph(context, getToken(statement.i)),
                          child: const Text('Show paths to Issuer'),
                        ),
                        ElevatedButton(
                          onPressed: () => _showGraph(context, statement.subjectToken),
                          child: const Text('Show paths to Subject'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGraph(BuildContext context, String focusIdentity) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => NerdyGraphView(
        controller: controller,
        initialFocus: focusIdentity,
      ),
    ));
  }
}
