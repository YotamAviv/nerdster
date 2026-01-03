import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/merger.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/keys.dart';

const String kOneofusContext = '<identity>';
const String kNerdsterContext = '<nerdster>';

/// The Pure Function Core of the Follow Network Algorithm.
///
/// Input: 
/// - A TrustGraph (Identity Layer)
/// - A DelegateResolver
/// - A map of org.nerdster statements by token
/// - The follow context (e.g., '<nerdster>', 'news')
/// Output: A FollowNetwork
FollowNetwork reduceFollowNetwork(
  TrustGraph trustGraph,
  DelegateResolver delegateResolver,
  ContentResult contentResult,
  String fcontext, {
  int maxDegrees = 6,
}) {
  assert(() {
    for (final entry in contentResult.delegateContent.entries) {
      Statement.validateStatementTimesAndTypes(entry.value);
    }
    return true;
  }());

  final List<String> identities = [];
  final List<TrustNotification> notifications = [];
  final Map<String, List<ContentStatement>> edges = {};
  final Map<String, List<String>> paths = {trustGraph.pov: [trustGraph.pov]};

  // 1. Handle <one-of-us> context (Identity Layer only)
  if (fcontext == kOneofusContext) {
    for (final token in trustGraph.orderedKeys) {
      final String canonical = trustGraph.resolveIdentity(token);
      if (identities.contains(canonical)) continue;
      identities.add(canonical);
      // For <identity> context, we can pull paths from the trustGraph
      final tgPaths = trustGraph.paths[canonical];
      if (tgPaths != null && tgPaths.isNotEmpty) {
        paths[canonical] = tgPaths.first;
      }
    }
    return FollowNetwork(
      fcontext: fcontext,
      identities: identities,
      povIdentity: trustGraph.pov,
      paths: paths,
      notifications: notifications,
      edges: edges,
    );
  }

  // 2. Handle <nerdster> and custom contexts
  final Map<String, int> followDistances = {trustGraph.pov: 0};
  final List<String> orderedIdentities = [trustGraph.pov];
  final Set<String> blocked = {};
  final Set<String> initialLayer = {trustGraph.pov};

  var layer = initialLayer;
  for (int dist = 0; dist < maxDegrees && layer.isNotEmpty; dist++) {
    final nextLayer = <String>{};

    for (final String issuerIdentity in layer) {
      // Get all follow/block statements from this identity's keys and its delegates
      final List<Iterable<ContentStatement>> sources = [];
      
      // Delegate Keys
      for (final String keyStr in delegateResolver.getDelegatesForIdentity(issuerIdentity)) {
        final key = DelegateKey(keyStr);
        final list = contentResult.delegateContent[key];
        if (list != null && list.isNotEmpty) sources.add(list);
      }

      final Iterable<ContentStatement> statements = Merger.merge<ContentStatement>(sources);
      
      final Set<String> decided = {};
      for (final ContentStatement s in statements) {
        if (s.verb != ContentVerb.follow) continue;
        
        // The subject of a follow statement is an identity.
        final String subjectIdentity = trustGraph.resolveIdentity(s.subjectToken);

        final Map<String, dynamic> contexts = s.contexts ?? {};
        final dynamic weight = contexts[fcontext];

        if (weight == null) continue;
        
        // Record the edge for the graph view
        edges.putIfAbsent(issuerIdentity, () => []).add(s);

        if (decided.contains(subjectIdentity)) continue;
        decided.add(subjectIdentity);

        final int w = weight is int ? weight : (weight is num ? weight.toInt() : num.parse(weight.toString()).toInt());

        if (w < 0) {
          // Block
          if (subjectIdentity == trustGraph.pov) {
            notifications.add(TrustNotification(
              reason: "Attempt to block you in context $fcontext",
              relatedStatement: s,
              isConflict: true,
            ));
            continue;
          }
          if (!followDistances.containsKey(subjectIdentity) || followDistances[subjectIdentity]! > dist) {
            blocked.add(subjectIdentity);
          } else {
            notifications.add(TrustNotification(
              reason: "Attempt to block followed identity $subjectIdentity in context $fcontext",
              relatedStatement: s,
              isConflict: true,
            ));
          }
        } else if (weight > 0) {
          // Follow
          if (blocked.contains(subjectIdentity)) {
            notifications.add(TrustNotification(
              reason: "Attempt to follow blocked identity $subjectIdentity in context $fcontext",
              relatedStatement: s,
              isConflict: true,
            ));
            continue;
          }
          if (!followDistances.containsKey(subjectIdentity)) {
            followDistances[subjectIdentity] = dist + 1;
            paths[subjectIdentity] = [...paths[issuerIdentity]!, subjectIdentity];
            orderedIdentities.add(subjectIdentity);
            nextLayer.add(subjectIdentity);
          }
        }
      }

      // Special case for <nerdster> context: also include WoT trusts
      if (fcontext == kNerdsterContext) {
        // Only identity keys can sign trust statements.
        final List<String> identityKeys = trustGraph.getEquivalenceGroup(issuerIdentity);
        for (final String key in identityKeys) {
          final List<TrustStatement> wotTrusts = trustGraph.edges[key] ?? [];
          for (final TrustStatement ts in wotTrusts) {
            if (ts.verb != TrustVerb.trust) continue;
            final String subjectIdentity = trustGraph.resolveIdentity(ts.subjectToken);
            if (decided.contains(subjectIdentity)) continue;
            
            if (blocked.contains(subjectIdentity)) continue;
            if (!followDistances.containsKey(subjectIdentity)) {
              followDistances[subjectIdentity] = dist + 1;
              paths[subjectIdentity] = [...paths[issuerIdentity]!, subjectIdentity];
              orderedIdentities.add(subjectIdentity);
              nextLayer.add(subjectIdentity);
            }
          }
        }
      }
    }
    layer = nextLayer;
  }

  final List<String> filteredIdentities = orderedIdentities.where((id) => !blocked.contains(id)).toList();

  return FollowNetwork(
    fcontext: fcontext,
    identities: filteredIdentities,
    povIdentity: trustGraph.pov,
    paths: paths,
    notifications: notifications,
    edges: edges,
  );
}
