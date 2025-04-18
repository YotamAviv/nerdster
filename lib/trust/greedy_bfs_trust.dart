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
      {Notifications? notifier,
      ProgressR? progressR,
      Future<void> Function(List<Node> tokens, int distance)? batchFetch}) async {
    LinkedHashMap<String, Node> network = LinkedHashMap<String, Node>();
    network[source.token] = source;
    assert(source.paths.isEmpty);

    Set<Node> visited = <Node>{};

    Queue<Path> currentLayer = Queue<Path>();
    currentLayer.addLast([Trust(source, date0, 'dummy')]);

    Queue<Path> nextLayer = Queue<Path>();

    int pass = 1; // degrees (plus/minus 1 ;)
    while (true) {
      if (b(batchFetch)) {
        List<Node> nodes = [];
        for (Path path in currentLayer) {
          assert(isValidPath(path, network)); // (This  used to be possible; code to address gone.)
          Node n = path.last.node;
          nodes.add(n);
        }
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
            notifier?.reject(block.statementToken, '''Don't block yourself.''');
            continue;
          }
          // Block the other node if allowed (not already trusted).
          /// I used to think (feel, assume) that it's good to give blocks preference over trusts.
          /// Greedy approach, briefly, simplified: If trusted then can't block.
          if (other == source) {
            // Special case, no paths
            notifier?.reject(block.statementToken, 'Attempt to block your key.');
            continue;
          }
          if (other.paths.isNotEmpty) {
            // Already trusted (not blocked, has paths, isn't blocked)
            assert(!other.blocked);
            assert(network.containsKey(other.token));
            notifier?.reject(block.statementToken, 'Attempt to block trusted key.');
            continue;
          }

          // Block allowed
          assert(!network.containsKey(other.token));
          assert(other.paths.isEmpty);

          other.blocked = true;
        }
      }

      // ====== REPLACES ====== //
      for (Path path in currentLayer) {
        assert(isValidPath(path, network));
        Node n = path.last.node;
        if (visited.contains(n)) continue;

        for (Replace replace in await n.replaces) {
          assert(b(replace.revokeAt));
          Node other = replace.node;
          if (other == n) {
            notifier?.reject(replace.statementToken, '''Don't replace yourself''');
            continue;
          }
          // Replace the other node if allowed.
          if (other == source) {
            // Special case, no paths
            notifier?.reject(replace.statementToken, 'Attempt to replace your key.');
            continue;
          }
          if (other.revokeAt != null) {
            // In the grand scheme of Oneofus trust, only one key should be able to claim to
            // be the replacement of another, and that should be the responsibilty of
            // web-of-trust equivalence [WotEquivalence], not this class.
            // That said: I don't want to implement revoking at different tokens in Fetcher,
            // and so I do enforce it here.
            notifier?.reject(replace.statementToken, 'Attempt to replace a replaced key.');
            continue;
          }
          if (other.blocked) {
            // Hmm.. if someone blocks your old key, you should probably be informed about it.
            // This might be that rejected replace (otherwise, it'd be a rejected block)
            notifier?.reject(replace.statementToken, 'Attempt to replace a blocked key.');
            continue;
          }
          if (other.paths.isNotEmpty) {
            // Already trusted (not blocked, has paths, isn't blocked)
            assert(!other.blocked);
            assert(network.containsKey(other.token));
            notifier?.reject(replace.statementToken, 'Attempt to replace trusted key.');
            continue;
          }

          // replace allowed
          network.putIfAbsent(other.token, () => other);
          final Path newPath = List.of(path)..add(replace);
          other.paths.add(newPath);
          assert(newPath.length == pass + 1);
          other.revokeAt = replace.revokeAt;
          await other.trusts; // Setting revoked require re-fetching for revokedAtTime
          // Add to queue if not already visited.
          if (!visited.contains(other)) {
            nextLayer.addLast(newPath);
          }
        }
      }

      // ====== TRUSTS ====== //
      // If pass > degrees, don't add more trusts, just blocks.
      if (pass < degrees) {
        for (Path path in currentLayer) {
          assert(isValidPath(path, network));
          Node n = path.last.node;
          if (visited.contains(n)) continue;
          visited.add(n);

          for (Trust trust in await n.trusts) {
            final Node other = trust.node;
            if (other == n) {
              notifier?.reject(trust.statementToken, '''Don't trust yourself.''');
              continue;
            }
            if (path.where((pathEdge) => pathEdge.node == other).isNotEmpty) {
              continue; // Don't let path cycle
            }

            if (other.blocked) {
              notifier?.reject(trust.statementToken, '''Attempt to trust blocked key.''');
              continue;
            }

            // Trust / further trust other node as necessary, create path, enqueue
            network.putIfAbsent(other.token, () => other);
            final Path newPath = List.of(path)..add(trust);
            other.paths.add(newPath);
            assert(newPath.length == pass + 1);

            // Add to queue if not already visited.
            if (!visited.contains(other)) {
              nextLayer.addLast(newPath);
            }
          }
        }
      }

      if (nextLayer.isEmpty) {
        break;
      }
      if (pass >= degrees) {
        break;
      }
      pass++;
      currentLayer = nextLayer;
      nextLayer = Queue<Path>();
    }

    // Remove nodes that were there just to remember that they're blocked.
    network.removeWhere((key, value) => value.blocked);

    // PERFORMANCE: print('now restricting...');

    // Validate, prune/restrict. Repeat until we're not removing more..
    // - validate: (we may have created paths using nodes that have later been blocked.)
    // - numPaths
    // - degrees
    int networkSizeBefore = network.length;
    while (true) {
      // Remove invalid paths (revoked nodes made edges, node no longer in network (not enough paths)),
      for (Node n in network.values) {
        if (n == source) continue; // Skip this for source.
        n.paths = List.of(n.paths.where((path) => isValidPath(path, network))); // TODO: Can probably remove
      }
      // Restrict to numPaths
      network.removeWhere((token, node) => (token != source.token) && node.paths.length < numPaths);

      // We're not removing, and so we're done.
      if (network.length == networkSizeBefore) break;
      
      networkSizeBefore = network.length;
    }

    if (b(progressR)) progressR!.report(1, 'Done');
    return network;
  }

  // Walk the path from source to last node.
  // TODO: Recent changes to be truly greedy can probably eliminate much of this as paths
  // can't become invalide (nodes can only be revmoed due to not enough paths, not revoked due to 
  // replacement) the way they used to.
  // - Each node should be in the network.
  // - OLD: Each edge should have statedAt before node was revoked (in case it was revoked)
  bool isValidPath(Path path, Map<String, Node> network) {
    if (path.length > degrees) return false;

    bool out = true;
    DateTime? fromRevokeAtTime; // (source)
    for (Trust edge in path.sublist(1)) {
      Node? to = network[edge.node.token];
      if (!b(to) || to!.blocked) {
        out = false;
        break;
      }

      // validate. TODO: remove
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
    // NOPE: assert(out, 'Checking. Turns out that now without blocker benefit, paths remain valid.');
    // When numPaths > 1, paths become invalid as the nodes leading to them are removed from the 
    // network due to that restriction.
    return out;
  }
}
