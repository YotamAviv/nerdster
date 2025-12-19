import 'dart:collection';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/model.dart';

typedef PathRequirement = int Function(int distance);

/// A Robust Trust Algorithm that requires multiple independent paths for distant nodes.
///
/// ## High-Level Algorithm
/// 1. **Layered Traversal**: We proceed layer by layer (Distance 0, 1, 2...).
/// 2. **Candidate Selection**: For a node `u` at distance `d`, we look at its trusted neighbors
///    to find candidates `v` at distance `d+1`.
/// 3. **Robustness Check**: Before accepting `v` into the graph, we verify that there are
///    enough *independent* paths from the Root to `v`.
///    - "Independent" means **Node-Disjoint**: paths share no common nodes (except Root and `v`).
///    - This ensures that no single intermediate node (or small clique) controls all trust paths to `v`.
/// 4. **Max Flow**: We use the Edmonds-Karp algorithm on a "Node-Split" graph to calculate
///    the maximum number of disjoint paths.
///
/// ## Trust Capping (Spam Defense)
/// To defend against "Trust Spam" (a compromised key vouching for thousands of Sybils),
/// we enforce a hard cap of 100 outgoing `trust` or `replace` statements per identity.
/// If an identity issues more, only the 100 most recent are considered.
/// `block` statements are not capped.
///
/// ## Complexity Analysis
/// - **BFS Traversal**: Standard $O(V + E)$.
/// - **Robustness Check**: For each candidate node, we run a Max Flow algorithm.
///   - We use Edmonds-Karp on a unit-capacity network (due to node splitting).
///   - Complexity of one Max Flow run: $O(V \cdot E)$ (for unit networks).
/// - **Total Complexity**: $O(V^2 \cdot E)$ in the worst case.
///
/// **Performance Note**:
/// While $O(V^2 E)$ sounds heavy, in practice:
/// 1. `V` is limited by `maxDegrees` (depth limit ~6).
/// 2. We only run Max Flow if `pathRequirement > 1`.
/// 3. The graph is sparse.
/// 4. This runs locally for a single user's perspective, not the global graph.
///
/// [pathRequirement] defines how many node-disjoint paths are needed at each distance.
/// Example: (d) => d <= 2 ? 1 : (d <= 4 ? 2 : 3);
TrustGraph computeRobustTrustGraph(
  TrustGraph current, 
  List<TrustStatement> statements,
  PathRequirement pathRequirement,
) {
  final Map<String, int> distances = {current.root: 0};
  final Map<String, String> replacements = {};
  final Map<String, String> revokeAtConstraints = Map.from(current.revokeAtConstraints);
  final Set<String> blocked = {};
  final List<TrustConflict> conflicts = [];
  final Map<String, List<TrustStatement>> edges = {};
  
  // --- 1. Index Statements ---
  final Map<String, List<TrustStatement>> byIssuer = {};
  final Map<String, TrustStatement> byToken = {};
  
  for (var s in statements) {
    byIssuer.putIfAbsent(s.iToken, () => []).add(s);
    byToken[s.token] = s;
  }

  DateTime? resolveRevokeAt(String? revokeAtToken) {
    if (revokeAtToken == null) return null;
    return byToken[revokeAtToken]?.time;
  }

  // --- 2. Robust BFS ---
  // We use a Priority Queue to process nodes by distance (simulating layers).
  // But since edge weights are 1, a standard Queue with 'nextLayer' logic works.
  
  // The set of nodes that are "Robustly Trusted".
  // Only these nodes can be used as intermediates in paths.
  final Set<String> trustedSet = {current.root};
  
  // Queue stores: Token
  final queue = Queue<String>();
  queue.add(current.root);
  
  // We track visited for the BFS traversal itself to avoid cycles/re-processing
  final visited = {current.root};

  int maxDegrees = 6;

  while (queue.isNotEmpty) {
    final issuer = queue.removeFirst();
    final dist = distances[issuer]!;
    
    if (dist >= maxDegrees) continue;

    // --- 3. Process Statements for Issuer ---
    var issuerStatements = byIssuer[issuer] ?? [];
    
    // Sort Newest First
    issuerStatements.sort((a, b) => b.time.compareTo(a.time));

    // Filter by revokeAt
    if (revokeAtConstraints.containsKey(issuer)) {
      final limitTime = resolveRevokeAt(revokeAtConstraints[issuer]);
      if (limitTime != null) {
        issuerStatements = issuerStatements.where((s) => !s.time.isAfter(limitTime)).toList();
      }
    }

    // --- CAP TRUSTS (Spam Defense) ---
    // TODO: Issue a warning to the user if they have > 100 active trust/replace statements.
    // We limit the number of active 'trust' and 'replace' statements to 100 to prevent
    // a single compromised or malicious key from flooding the network.
    // We keep the 100 most recent. Blocks are unaffected.
    var trustCount = 0;
    issuerStatements = issuerStatements.where((s) {
      final isCapped = s.verb == TrustVerb.trust || s.verb == TrustVerb.replace;
      return !isCapped || trustCount++ < 100;
    }).toList();

    // Store valid edges
    edges[issuer] = issuerStatements;

    // Handle Blocks
    for (var s in issuerStatements.where((s) => s.verb == TrustVerb.block)) {
      if (trustedSet.contains(s.subjectToken)) {
        conflicts.add(TrustConflict(s.subjectToken, "Blocked by $issuer", [s.token]));
      } else {
        blocked.add(s.subjectToken);
      }
    }

    // Handle Replaces
    for (var s in issuerStatements.where((s) => s.verb == TrustVerb.replace)) {
      final oldKey = s.subjectToken;
      if (trustedSet.contains(oldKey)) {
         // If we already trusted the old key, this is a valid rotation (or conflict)
         // For simplicity in this robust algo, we accept it if the new key (issuer) is trusted.
         // Since 'issuer' is popped from queue, it IS trusted.
      }
      replacements[oldKey] = issuer;
      if (s.revokeAt != null) {
        revokeAtConstraints[oldKey] = s.revokeAt!;
      }
    }

    // Handle Trusts (Expand Frontier)
    for (var s in issuerStatements.where((s) => s.verb == TrustVerb.trust)) {
      var subject = s.subjectToken;
      if (replacements.containsKey(subject)) {
        subject = replacements[subject]!;
      }

      if (blocked.contains(subject)) continue;
      if (visited.contains(subject)) continue;

      // --- 4. Robustness Check ---
      // We found a candidate 'subject' at potential distance 'dist + 1'.
      // Check if we have enough independent paths from Root to Subject.
      // The paths must use only nodes in 'trustedSet' (plus the subject).
      
      final required = pathRequirement(dist + 1);
      
      // Optimization: If required is 1, BFS guarantee is enough.
      bool isRobust = true;
      if (required > 1) {
        // Build local adjacency graph for Max Flow
        // We only include edges (u -> v) where u is in trustedSet.
        // And v is either in trustedSet or is the subject.
        final flow = _calculateNodeDisjointPaths(
          current.root, 
          subject, 
          trustedSet, 
          edges, // Uses the filtered edges we just computed
          byToken,
          replacements
        );
        if (flow < required) {
          isRobust = false;
        }
      }

      if (isRobust) {
        visited.add(subject);
        trustedSet.add(subject);
        distances[subject] = dist + 1;
        queue.add(subject);
        
        // Also add the replaced key if applicable (it's trusted via the new key)
        if (s.subjectToken != subject) {
           distances[s.subjectToken] = dist + 1;
           // We don't queue the old key for traversal, usually.
        }
      }
    }
  }

  return TrustGraph(
    root: current.root,
    distances: distances,
    replacements: replacements,
    revokeAtConstraints: revokeAtConstraints,
    blocked: blocked,
    conflicts: conflicts,
    edges: edges,
  );
}

/// Calculates the number of node-disjoint paths from source to sink.
/// Uses Edmonds-Karp on a node-split graph.
int _calculateNodeDisjointPaths(
  String source,
  String sink,
  Set<String> allowedNodes,
  Map<String, List<TrustStatement>> edges,
  Map<String, TrustStatement> byToken,
  Map<String, String> replacements,
) {
  // 1. Build Capacity Graph (Adjacency List)
  // Nodes are split: "u_in" and "u_out".
  // Edge u_in -> u_out has capacity 1 (except Source and Sink which are inf).
  // Trust u -> v becomes u_out -> v_in with capacity 1.
  
  final capacity = <String, Map<String, int>>{};
  
  void addEdge(String u, String v, int cap) {
    capacity.putIfAbsent(u, () => {})[v] = cap;
    capacity.putIfAbsent(v, () => {})[u] = 0; // Residual
  }

  final nodes = allowedNodes.toList()..add(sink);
  
  for (var node in nodes) {
    // Split node constraint (skip for source/sink to allow multiple paths leaving/entering)
    if (node != source && node != sink) {
      addEdge('${node}_in', '${node}_out', 1);
    }
    
    // Trust edges
    // Only process outgoing edges from this node if it's in the edges map
    if (edges.containsKey(node)) {
      for (var s in edges[node]!.where((s) => s.verb == TrustVerb.trust)) {
        var target = s.subjectToken;
        if (replacements.containsKey(target)) target = replacements[target]!;
        
        if (nodes.contains(target)) {
          // Edge: node_out -> target_in
          String u = (node == source) ? source : '${node}_out';
          String v = (target == sink) ? sink : '${target}_in';
          addEdge(u, v, 1);
        }
      }
    }
  }

  // 2. Edmonds-Karp
  int flow = 0;
  while (true) {
    final parent = <String, String>{};
    final queue = Queue<String>();
    queue.add(source);
    
    while (queue.isNotEmpty) {
      final u = queue.removeFirst();
      if (u == sink) break;
      
      final neighbors = capacity[u]?.keys ?? [];
      for (var v in neighbors) {
        if (!parent.containsKey(v) && v != source && (capacity[u]![v] ?? 0) > 0) {
          parent[v] = u;
          queue.add(v);
        }
      }
    }
    
    if (!parent.containsKey(sink)) break; // No augmenting path
    
    flow++;
    
    // Update residual capacities
    String curr = sink;
    while (curr != source) {
      final prev = parent[curr]!;
      capacity[prev]![curr] = capacity[prev]![curr]! - 1;
      capacity[curr]![prev] = capacity[curr]![prev]! + 1;
      curr = prev;
    }
  }
  
  return flow;
}
