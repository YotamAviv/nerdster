// PLAN:
// 1. Remove the text-based path visualization (_buildPathSpans and its usage).
// 2. Add "Show Trust Graph" buttons/links to the notification dialog.
//    - One for paths to the Issuer.
//    - One for paths to the Subject.
// 3. Implement a `StaticFeedController` to adapt the existing `TrustGraph` and `FollowNetwork` 
//    into a `V2FeedController` required by `NerdyGraphView`.
// 4. Launch `NerdyGraphView` in a dialog or new screen when the buttons are clicked.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:nerdster/menus.dart';
import 'package:nerdster/v2/interpreter.dart';
import 'package:nerdster/v2/json_display.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/model.dart';
import 'package:float_column/float_column.dart';
import 'package:nerdster/v2/graph_view.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/cached_source.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:url_launcher/url_launcher.dart';

class V2NotificationsMenu extends StatelessWidget {
  final TrustGraph? trustGraph;
  final FollowNetwork? followNetwork;
  final V2Labeler labeler;

  const V2NotificationsMenu(
      {super.key, this.trustGraph, this.followNetwork, required this.labeler});

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
              content:
                  _V2StatementNotification(notification, labeler: labeler, trustGraph: trustGraph, followNetwork: followNetwork),
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
  final TrustGraph? trustGraph;
  final FollowNetwork? followNetwork;

  const _V2StatementNotification(this.notification, {required this.labeler, this.trustGraph, this.followNetwork});

  @override
  Widget build(BuildContext context) {
    final Statement statement = notification.relatedStatement;
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
                      child: V2JsonDisplay(jsonish.json, interpreter: V2Interpreter(labeler)),
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
                          onPressed: () => _showGraph(context, statement.iToken),
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
    if (trustGraph == null) return;
    
    final model = V2FeedModel(
      trustGraph: trustGraph!,
      followNetwork: followNetwork ?? FollowNetwork(
        fcontext: 'identity',
        povIdentity: trustGraph!.pov,
      ),
      labeler: labeler,
      aggregation: ContentAggregation(),
      povToken: trustGraph!.pov,
      fcontext: 'identity',
      sortMode: V2SortMode.recentActivity,
      filterMode: V2FilterMode.ignoreDisses,
      enableCensorship: false,
    );
    
    final controller = StaticFeedController(model);
    
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => NerdyGraphView(
        controller: controller,
        initialFocus: focusIdentity,
      ),
    ));
  }
}

class DummySource<T extends Statement> implements StatementSource<T> {
  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async => {};
  
  @override
  List<TrustNotification> get notifications => [];
}

class StaticFeedController extends ValueNotifier<V2FeedModel?> implements V2FeedController {
  StaticFeedController(V2FeedModel value) : super(value);

  @override
  CachedSource<ContentStatement> get contentSource => CachedSource(DummySource<ContentStatement>());

  @override
  CachedSource<TrustStatement> get trustSource => CachedSource(DummySource<TrustStatement>());

  @override
  Future<void> refresh(String? povIdentityToken, {String? meIdentityToken}) async {}

  @override
  bool get loading => false;
  
  @override
  ValueNotifier<double> get progress => ValueNotifier(0);
  
  @override
  ValueNotifier<String?> get loadingMessage => ValueNotifier(null);
  
  @override
  String? get error => null;

  @override
  V2SortMode get sortMode => V2SortMode.recentActivity;
  @override
  set sortMode(V2SortMode mode) {}

  @override
  V2FilterMode get filterMode => V2FilterMode.ignoreDisses;
  @override
  set filterMode(V2FilterMode mode) {}

  @override
  String? get tagFilter => null;
  @override
  set tagFilter(String? tag) {}

  @override
  String? get typeFilter => null;
  @override
  set typeFilter(String? type) {}

  @override
  bool get enableCensorship => false;
  @override
  set enableCensorship(bool enable) {}

  @override
  bool shouldShow(SubjectAggregation subject, V2FilterMode mode, bool censorshipEnabled,
      {String? tagFilter, Map<String, String>? tagEquivalence, String? typeFilter}) => true;

  @override
  void sortSubjects(List<SubjectAggregation> subjects) {}
}
