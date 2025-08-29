import 'dart:collection';

import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/progress.dart';
import 'package:nerdster/trust/trust.dart';

/// Greed BFS trust algorithm
/// At each layer, process [block, replace, trust] statements in that order
///
/// A significant change at build #84: Truly greedy, can't replace trusted node.
/// This clears up:
/// - Formerly in NetTile: Can an EG (smiley) be revoked/replaced?
/// - various "beheading" scenarios where X trusts (or replaces) Y trusts Z revokes Y.
/// Odds are good that remants of this past remains in the code and docs.
///
/// Side effects:
/// - Fetchers (Nodes) in network should be fully fetched (cached).
/// - Rejections (due to conflict) of statements should be complete (equivalence relies on this).
///   To facilitate this, we loop 1 extra degree.
///
/// DEFER: We don't add trusts (or replaces, blocks) when processing the last layer, but we
/// do fetch the statements so that we have everyone's statements. This isn't clean or correct as
/// those statements are not rejected as conflicts, but they're not acted on here; LeyLabels, for
/// example, mighht use them affect someone's name.
///
/// TODO: time limit
/// TODO: network size max
///
/// DEFER: Consider network order/ranking. Right now their in the order we discover them in
/// the BFS, not terrible.

class GreedyBfsTrust {
  final int degrees; // 1 degree is just me.
  final int numPaths;

  GreedyBfsTrust({this.degrees = 6, this.numPaths = 1});

  Future<LinkedHashMap<String, Node>> process(Node source,
      {BaseProblemCollector? problemCollector,
      ProgressR? progressR,
      Future<void> Function(Iterable<Node> tokens, int distance)? batchFetch}) async {
    LinkedHashMap<String, Node> network = LinkedHashMap<String, Node>();
    network[source.token] = source;
    assert(source.paths.isEmpty);

    Set<Node> visited = <Node>{};

    Queue<Path> currentLayer = Queue<Path>();
    currentLayer.addLast([Trust(source, date0, 'dummy')]);

    Queue<Path> nextLayer = Queue<Path>();

    // At pass n, we build paths of length n+1.
    // We nake a gratuitous loop to fetch and reject statements by last layer of nodes.
    for (int pass = 1; pass < degrees + 1; pass++) {
      if (b(batchFetch)) {
        Iterable<Node> nodes = currentLayer.map((p) => p.last.node);
        await batchFetch!(nodes, pass);
      }
      if (b(progressR)) progressR!.report(pass / degrees, 'degrees: $pass');

      // ====== BLOCKS ====== //
      for (Path path in currentLayer) {
        assert(isValidPath(path, network));
        Node n = path.last.node;

        for (Block block in await n.blocks) {
          Node other = block.node;
          if (other.blocked) continue;
          if (other == n) {
            problemCollector?.reject(block.statementToken, '''Don't block yourself.''');
            continue;
          }
          // Block the other node if allowed (not already trusted).
          /// I used to think (feel, assume) that it's good to give blocks preference over trusts.
          /// Greedy approach, briefly, simplified: If trusted then can't block.
          if (other == source) {
            // Special case, no paths
            problemCollector?.reject(block.statementToken, 'Attempt to block your key.');
            continue;
          }
          if (other.paths.isNotEmpty) {
            // Already trusted (not blocked, has paths, isn't blocked)
            assert(!other.blocked);
            assert(network.containsKey(other.token));
            problemCollector?.reject(block.statementToken, 'Attempt to block trusted key.');
            continue;
          }

          // Block allowed
          if (pass < degrees) {
            assert(!network.containsKey(other.token));
            assert(other.paths.isEmpty);
            other.blocked = true;
          }
        }
      }

      // ====== REPLACES ====== //
      for (Path path in currentLayer) {
        assert(isValidPath(path, network));
        Node n = path.last.node;
        visited.add(n);

        for (Replace replace in await n.replaces) {
          assert(b(replace.revokeAt));
          Node other = replace.node;
          // Replace the other node if allowed.
          if (other == n) {
            problemCollector?.reject(replace.statementToken, '''Don't replace yourself''');
            continue;
          }
          if (other == source) {
            problemCollector?.reject(replace.statementToken, 'Attempt to replace your key.');
            continue;
          }
          if (other.revokeAt != null) {
            // In the grand scheme of Oneofus trust, only one key should be able to claim to
            // be the replacement of another, and that should be the responsibilty of
            // web-of-trust equivalence [WotEquivalence], not this class.
            // That said: I don't want to implement revoking at different tokens in Fetcher,
            // and so I do enforce it here.

            // BUG: Possible bug, forgot the details, oops.
            problemCollector?.reject(replace.statementToken, 'Attempt to replace a replaced key.');
            continue;
          }
          if (other.blocked) {
            // Hmm.. if someone blocks your old key, you should probably be informed about it.
            // This might be that rejected replace (otherwise, it'd be a rejected block)
            problemCollector?.reject(replace.statementToken, 'Attempt to replace a blocked key.');
            continue;
          }
          if (other.paths.isNotEmpty) {
            assert(!other.blocked);
            assert(network.containsKey(other.token));
            problemCollector?.reject(replace.statementToken, 'Attempt to replace trusted key.');
            continue;
          }

          // replace allowed
          if (pass < degrees) {
            network.putIfAbsent(other.token, () => other);
            final Path newPath = List.of(path)..add(replace);
            other.paths.add(newPath);
            assert(newPath.length == pass + 1);
            other.revokeAt = replace.revokeAt;
            // QUESTIONABLE: OLD: await other.trusts; // re-fetch after setting revokeAt
            // Add to queue if not already visited.
            if (!visited.contains(other)) nextLayer.addLast(newPath);
          }
        }
      }

      // ====== TRUSTS ====== //
      for (Path path in currentLayer) {
        assert(isValidPath(path, network));
        Node n = path.last.node;

        for (Trust trust in await n.trusts) {
          final Node other = trust.node;
          if (other == n) {
            problemCollector?.reject(trust.statementToken, '''Don't trust yourself.''');
            continue;
          }
          if (other.blocked) {
            problemCollector?.reject(trust.statementToken, '''Attempt to trust blocked key.''');
            continue;
          }
          if (path.where((pathEdge) => pathEdge.node == other).isNotEmpty) continue; // cycle
          // Trust / further trust allowed
          if (pass < degrees) {
            network.putIfAbsent(other.token, () => other);
            final Path newPath = List.of(path)..add(trust);
            other.paths.add(newPath);
            assert(newPath.length == pass + 1, '${newPath.length} == ${pass + 1}');
            // Add to queue if not already visited.
            if (!visited.contains(other)) nextLayer.addLast(newPath);
          }
        }
      }

      if (nextLayer.isEmpty) break;
      currentLayer = nextLayer;
      nextLayer = Queue<Path>();
    }

    // Remove nodes that were there just to remember that they're blocked.
    network.removeWhere((key, value) => value.blocked);

    restrict(source, network);

    if (b(progressR)) progressR!.report(1, 'Done');
    return network;
  }

  void restrict(Node source, LinkedHashMap<String, Node> network) {
    // Validate, prune/restrict. Repeat until we're not removing more..
    int networkSizeBefore = network.length;
    while (true) {
      // Remove invalid paths (paths with node removed from network due to not enough paths),
      for (Node n in network.values) {
        if (n == source) continue; // source.
        n.paths = List.of(n.paths.where((path) => isValidPath(path, network)));
      }

      // Remove nodes with not enough paths
      network.removeWhere((token, node) => (token != source.token) && node.paths.length < numPaths);

      // We're done when we're not removing any more.
      if (network.length == networkSizeBefore) break;
      networkSizeBefore = network.length;
    }
  }

  // Walk the path from source to last node.
  // DEFER: Due to recent changes to be truly greedy (trusted nodes don't get replaced (revoked)),
  // this can be made simpler.
  // - Each node should be in the network.
  // - (OLD: Each edge should have statedAt before node was revoked (in case it was revoked))
  bool isValidPath(Path path, Map<String, Node> network) {
    assert(path.length <= degrees);
    bool out = true;
    DateTime? fromRevokeAtTime; // (source)
    for (Trust edge in path.sublist(1)) {
      Node? to = network[edge.node.token];
      if (!b(to) || to!.blocked) {
        out = false;
        break;
      }
      // validate.
      if (fromRevokeAtTime != null && fromRevokeAtTime.isBefore(edge.statedAt)) {
        out = false;
        assert(out, "Checking. No path contains revoked edges.");
        break;
      }
      // compute fromRevokeAtTime for next iteration
      String? fromRevokeAt = network[edge.node.token]!.revokeAt;
      fromRevokeAtTime = network[edge.node.token]!.revokeAtTime;
      if (fromRevokeAt != null) {
        // The only case where we should have fromRevokeAtTime != null is if it's the last path
        // (which we didn't take, and so it wasn't fetched.)
        assert(fromRevokeAtTime != null || edge.node.token == path.last.node.token);
      }
    }
    // print ('isValidPath(${List.from(path.map((e) => e.node.token))} returning $out');
    return out;
  }
}
