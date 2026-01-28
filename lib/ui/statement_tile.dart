import 'package:flutter/material.dart';
import 'package:nerdster/comment_widget.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/logic/interpreter.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/ui/json_display.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/ui/dialogs/rate_dialog.dart';

// Question: Do ... canonical/equivalent..?
class StatementTile extends StatelessWidget {
  final ContentStatement statement;
  final FeedModel model;
  final FeedController controller;
  final int depth;
  final SubjectAggregation aggregation;
  final ValueChanged<String?>? onGraphFocus;
  final ValueChanged<ContentKey?>? onMark;
  final ValueNotifier<ContentKey?>? markedSubjectToken;
  final ValueChanged<ContentKey>? onInspect;
  final ValueChanged<String>? onTagTap;
  final int? maxLines;

  const StatementTile({
    super.key,
    required this.statement,
    required this.model,
    required this.controller,
    required this.depth,
    required this.aggregation,
    this.onGraphFocus,
    this.onMark,
    this.markedSubjectToken,
    this.onInspect,
    this.onTagTap,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final s = statement;
    final label = model.labeler.getLabel(s.iToken);

    // Find the aggregation for this statement (s)
    final ContentKey canonicalToken =
        model.aggregation.equivalence[ContentKey(s.token)] ?? ContentKey(s.token);
    final statementAgg = model.aggregation.subjects[canonicalToken];

    // Combine statements from the main aggregation (if any are threaded there) and the statement's own aggregation
    final repliesInParent =
        aggregation.statements.where((ContentStatement r) => r.subjectToken == s.token).toList();
    final combinedStatements = [
      ...repliesInParent,
      ...(statementAgg?.statements ?? <ContentStatement>[]),
    ];
    // Deduplicate based on token
    final List<ContentStatement> uniqueStatements =
        {for (var s in combinedStatements) s.token: s}.values.toList();

    // Determine current user's reaction to this statement
    final myReplies = uniqueStatements.where((r) {
      if (!signInState.isSignedIn) return false;
      final myIdentityKey = IdentityKey(signInState.identity);
      if (model.trustGraph.isTrusted(IdentityKey(r.iKey.value))) {
        return model.trustGraph.resolveIdentity(IdentityKey(r.iKey.value)) == myIdentityKey;
      }
      return model.delegateResolver.getIdentityForDelegate(r.iKey) == myIdentityKey;
    }).toList();

    IconData icon = Icons.rate_review_outlined;
    Color? color;
    String tooltip;

    if (myReplies.isNotEmpty) {
      color = Colors.blue;
      tooltip = 'You replied to this';
    } else {
      color = Colors.grey;
      tooltip = 'React';
    }

    // Determine display elements based on verb
    Widget? verbIcon;
    String? displayText;
    ContentKey? otherToken;

    final ContentKey thisToken = aggregation.token;
    final ContentKey thisCanonical = aggregation.canonical;

    if (s.verb == ContentVerb.rate) {
      // Icons are handled in the row, text is handled in subtitle or here if comment
    } else {
      // Determine target subject (needed for directional arrows too)
      if (s.other != null) {
        final sOtherTokenStr = getToken(s.other);
        final ContentKey sOtherToken = ContentKey(sOtherTokenStr);
        // If the statement's subject is THIS card, then the target is s.other
        // If the statement's other is THIS card, then the target is s.subject
        final ContentKey otherCanonical = model.aggregation.equivalence[sOtherToken] ?? sOtherToken;

        if (sOtherToken == thisToken) {
          otherToken = ContentKey(s.subjectToken);
          displayText = s.subject['title'];
        } else if (ContentKey(s.subjectToken) == thisToken) {
          otherToken = sOtherToken;
          displayText = s.other['title'];
        } else if (otherCanonical == thisCanonical) {
          otherToken = ContentKey(s.subjectToken);
          displayText = s.subject['title'];
        } else {
          // Default to other if subject is us, or if neither/both are us.
          otherToken = sOtherToken;
          displayText = s.other['title'];
        }
      }

      // Relations
      if (s.verb == ContentVerb.relate) {
        verbIcon = const Text('≈', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
      } else if (s.verb == ContentVerb.dontRelate) {
        verbIcon = const Text('≉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
      } else if (s.verb == ContentVerb.equate) {
        Widget icon = const Icon(Icons.compare_arrows, size: 18, color: Colors.blueGrey);
        if (otherToken != null) {
          final ContentKey otherCanonical = model.aggregation.equivalence[otherToken] ?? otherToken;
          final bool isThisCanonical = (thisToken == thisCanonical);
          final bool isOtherCanonical = (otherToken == otherCanonical);

          if (isThisCanonical && !isOtherCanonical) {
            icon = const Icon(Icons.arrow_back, size: 16);
          } else if (!isThisCanonical && isOtherCanonical) {
            icon = const Icon(Icons.arrow_forward, size: 16);
          }
        }
        verbIcon = icon;
      } else if (s.verb == ContentVerb.dontEquate) {
        verbIcon = const Text('≠', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
      }
    }

    return Container(
      padding: EdgeInsets.only(left: 16.0 + (depth * 16.0), right: 16.0, top: 4.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => onGraphFocus?.call(s.iToken),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (s.like == true) ...[
                const Icon(Icons.thumb_up, size: 12, color: Colors.green),
                const SizedBox(width: 2),
              ],
              if (s.like == false) ...[
                const Icon(Icons.thumb_down, size: 12, color: Colors.red),
                const SizedBox(width: 2),
              ],
              if (s.censor == true) ...[
                const Icon(Icons.delete, size: 12, color: Colors.red),
                const SizedBox(width: 2),
              ],
              if (s.comment != null && s.comment!.isNotEmpty) ...[
                const Icon(Icons.chat_bubble_outline, size: 12, color: Colors.grey),
                const SizedBox(width: 2),
              ],
              if (verbIcon != null) ...[
                const SizedBox(width: 4),
                verbIcon,
                const SizedBox(width: 4),
              ],
              if (displayText != null)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (otherToken != null && onInspect != null) {
                        onInspect!(otherToken!);
                      }
                    },
                    child: Text(
                      displayText,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              else
                const Spacer(),
              /* CONSIDER: Enable and fix if/when I decide to allow relating statements
              if (onMark != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.link,
                    size: 16,
                    color: markedSubjectToken == s.token ? Colors.orange : Colors.grey,
                  ),
                  tooltip: markedSubjectToken == s.token ? 'Unmark' : 'Mark to Relate/Equate',
                  onPressed: () {
                    if (checkDelegate(context)) {
                      onMark!(s.token);
                    }
                  },
                ),
              */
              if (uniqueStatements.isNotEmpty) ...[
                Text(
                  '${uniqueStatements.length} ${uniqueStatements.length == 1 ? "reaction" : "reactions"}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(icon, size: 16, color: color),
                tooltip: tooltip,
                onPressed: () async {
                  final group = SubjectGroup(
                    canonical: ContentKey(s.token),
                    statements: uniqueStatements,
                    lastActivity: s.time,
                  );
                  await RateDialog.show(
                    context,
                    SubjectAggregation(
                      subject: s.json,
                      group: group,
                      narrowGroup: group,
                    ),
                    controller,
                    intent: RateIntent.none,
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: Setting.get<bool>(SettingType.showCrypto),
                builder: (context, showCrypto, _) {
                  if (!showCrypto) return const SizedBox.shrink();
                  return IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.verified_user, size: 16, color: Colors.blue),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cryptographic Proof'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: JsonDisplay(s.json, interpreter: NerdsterInterpreter(model.labeler)),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context), child: const Text('Close')),
                        ],
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ],
          ),
          // BUG: We need to show who made ratings without comments.. who's like, dislike, etc.
          if (s.comment != null && s.comment!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 0.0, top: 2.0),
              child: CommentWidget(
                text: s.comment!,
                onHashtagTap: (tag, _) => onTagTap?.call(tag),
                style: const TextStyle(fontSize: 13),
                maxLines: maxLines,
              ),
            ),
        ],
      ),
    );
  }
}
