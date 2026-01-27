// PLAN:
// 1. Remove the text-based path visualization (_buildPathSpans and its usage).
// 2. Add "Show Trust Graph" buttons/links to the notification dialog.
//    - One for paths to the Issuer.
//    - One for paths to the Subject.
// 3. Implement a `StaticFeedController` to adapt the existing `TrustGraph` and `FollowNetwork`
//    into a `V2FeedController` required by `NerdyGraphView`.
// 4. Launch `NerdyGraphView` in a dialog or new screen when the buttons are clicked.

import 'package:float_column/float_column.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart'; // For getToken
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/cached_source.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/graph_view.dart';
import 'package:nerdster/v2/interpreter.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/json_display.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/source_error.dart';
import 'package:url_launcher/url_launcher.dart';

class V2NotificationsMenu extends StatelessWidget {
  final TrustGraph? trustGraph;
  final FollowNetwork? followNetwork;
  final DelegateResolver? delegateResolver;
  final V2Labeler labeler;
  final List<SourceError> sourceErrors;

  const V2NotificationsMenu({
    super.key,
    this.trustGraph,
    this.followNetwork,
    this.delegateResolver,
    required this.labeler,
    this.sourceErrors = const [],
  });

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

    // Check for "Not in network" warning
    final myIdentity = signInState.identity;
    if (followNetwork != null) {
      final canonicalIdentity =
          trustGraph?.resolveIdentity(IdentityKey(myIdentity)) ?? IdentityKey(myIdentity);
      if (!followNetwork!.identities.contains(canonicalIdentity)) {
        items.add(MenuItemButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const AlertDialog(
                title: Text("You're not in this network"),
                content: Text(
                    "Your identity is not included among the identities defining the view you are seeing.\n\n"
                    "This means your posts and actions may not be visible to others in this context."),
              ),
            );
          },
          child:
              const Text("⚠️ You're not in this network", style: TextStyle(color: Colors.orange)),
        ));
      }
    }

    // Check for "Delegate key revoked" warning
    final myDelegate = signInState.delegate;
    if (myDelegate != null && trustGraph != null) {
      // Check if the delegate key is replaced
      if (trustGraph!.replacements.containsKey(IdentityKey(myDelegate))) {
        items.add(MenuItemButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const AlertDialog(
                title: Text("Your delegate key is revoked"),
                content: Text(
                    "Your current delegate key has been replaced or revoked by your identity.\n\n"
                    "You cannot perform actions (like posting or liking) until you sign in with a valid key."),
              ),
            );
          },
          child: const Text("⛔ Your delegate key is revoked", style: TextStyle(color: Colors.red)),
        ));
      } else if (trustGraph!.isTrusted(IdentityKey(myIdentity))) {
        // Check if the delegate key is associated with the identity
        // We can check if the identity has a 'delegate' statement for this key in the graph edges
        bool isAssociated = false;
        final statements = trustGraph!.edges[IdentityKey(myIdentity)];
        if (statements != null) {
          for (final s in statements) {
            if (s.verb == TrustVerb.delegate && s.subjectToken == myDelegate) {
              isAssociated = true;
              break;
            }
          }
        }

        if (!isAssociated) {
          items.add(MenuItemButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AlertDialog(
                  title: Text("Delegate key not associated"),
                  content: Text("Your current delegate key is not associated with your identity."),
                ),
              );
            },
            child: const Text("⛔ Delegate key not associated", style: TextStyle(color: Colors.red)),
          ));
        }
      }
    }

    for (final notification in allNotifications) {
      items.add(_buildNotificationItem(notification, context));
    }

    Color? color = items.isNotEmpty ? Colors.red : null;
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
                child: _V2StatementNotification(notification,
                    labeler: labeler, trustGraph: trustGraph, followNetwork: followNetwork),
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
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(reason, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _V2StatementNotification extends StatelessWidget {
  final TrustNotification notification;
  final V2Labeler labeler;
  final TrustGraph? trustGraph;
  final FollowNetwork? followNetwork;

  const _V2StatementNotification(this.notification,
      {required this.labeler, this.trustGraph, this.followNetwork});

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
    if (trustGraph == null) return;

    final model = V2FeedModel(
      trustGraph: trustGraph!,
      followNetwork: followNetwork ??
          FollowNetwork(
            fcontext: 'identity',
            povIdentity: trustGraph!.pov,
          ),
      delegateResolver: labeler.delegateResolver ?? DelegateResolver(trustGraph!),
      labeler: labeler,
      aggregation: ContentAggregation(),
      povIdentity: trustGraph!.pov,
      fcontext: 'identity',
      sortMode: V2SortMode.recentActivity,
      filterMode: DisFilterMode.ignore,
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

// TODO: Justify or remove
class DummySource<T extends Statement> implements StatementSource<T> {
  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async => {};

  @override
  List<SourceError> get errors => [];
}

// TODO: Justify or remove
class StaticFeedController extends ValueNotifier<V2FeedModel?> implements V2FeedController {
  StaticFeedController(V2FeedModel value) : super(value);

  @override
  CachedSource<ContentStatement> get contentSource => CachedSource(DummySource<ContentStatement>());

  @override
  CachedSource<TrustStatement> get trustSource => CachedSource(DummySource<TrustStatement>());

  @override
  Future<Statement?> push(Json json, StatementSigner signer, {required BuildContext context}) async => null;

  @override
  Future<void> refresh({IdentityKey? pov, IdentityKey? meIdentity}) async {}

  @override
  Future<void> notify() async {}

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
  DisFilterMode get filterMode => DisFilterMode.ignore;
  @override
  set filterMode(DisFilterMode mode) {}

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
  ValueNotifier<bool> get enableCensorshipNotifier => ValueNotifier(false);

  @override
  bool shouldShow(SubjectAggregation subject, DisFilterMode mode, bool censorshipEnabled,
          {String? tagFilter,
          String? typeFilter,
          required ContentAggregation aggregation}) =>
      true;

  @override
  void sortSubjects(List<SubjectAggregation> subjects) {}
}
