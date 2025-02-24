import 'dart:collection';

import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/trust/trust.dart';

/// TODO: time limit
/// TODO: network size max

/// Trust1 algorithm: Layered, greedy BFS
/// At each layer, process in this order
/// - block statements
/// - replace statements
/// - trust statements
///
/// Note: I can trust the same nerd multiple times by using my own equivalents.
/// This shouldn't be a big deal as long as folks don't trust me more
/// than once, the path count from their point of view should be unaffected.
/// Folks should see notifications about trusting a non-equivalent key, which they should respond to by:
/// - touching base with the person (based on their comments and moniker) and verfiying and then:
/// - [trust the new key, clear trust for the old key].

/// DEFER: Consider network order/ranking. Right now their in the order we discover them in
/// the BFS, not terrible.

class Trust1 {
  final Map<String, String> _rejected = <String, String>{};
  final int degrees; // 1 degree is just me.
  final int numPaths;

  Map<String, String> get rejected => _rejected;

  Trust1({this.degrees = 6, this.numPaths = 1});

  Future<LinkedHashMap<String, Node>> process(Node source) async {
    LinkedHashMap<String, Node> network = LinkedHashMap<String, Node>();
    network[source.token] = source;
    assert(source.paths.isEmpty);

    Set<Node> visited = <Node>{};

    Queue<Path> currentLayer = Queue<Path>();
    currentLayer.addLast([Trust(source, date0, 'dummy')]);

    Queue<Path> nextLayer = Queue<Path>();

    int pass = 1; // degrees (plus/minus 1 ;)
    while (true) {
      print('.');
      Set<Path> removeAfterIteration = <Path>{};

      // ====== BLOCKS ====== //
      for (Path path in currentLayer) {
        if (!isValidPath(path, network)) {
          removeAfterIteration.add(path);
          continue;
        }
        Node n = path.last.node;

        for (Block block in await n.blocks) {
          Node other = block.node;
          if (other.blocked) continue;
          if (other == n) {
            _rejected[block.statementToken] = '''Don't block yourself.''';
            continue;
          }

          // Block the other node if allowed (not already trusted).
          /// I used to think (feel, assume) that it's good to give blocks preference over trusts.
          /// Greedy approach, briefly, simplified: If trusted then can't block.
          if (other == source) {
            // Special case, no paths
            _rejected[block.statementToken] = 'Attempt to block your key.';
            continue;
          }
          if (other.paths.isNotEmpty) {
            // Already trusted (not blocked, has paths, isn't blocked)
            assert(!other.blocked);
            assert(network.containsKey(other.token));
            _rejected[block.statementToken] = 'Attempt to block trusted key.';
            continue;
          }

          // Block allowed
          assert(!network.containsKey(other.token));
          assert(other.paths.isEmpty);

          other.blocked = true;
        }
      }
      currentLayer.removeWhere((p) => removeAfterIteration.contains(p));

      // ====== REPLACES ====== //
      for (Path path in currentLayer) {
        if (!isValidPath(path, network)) {
          removeAfterIteration.add(path);
          continue;
        }
        Node n = path.last.node;
        if (visited.contains(n)) continue;

        for (Replace replace in await n.replaces) {
          assert(b(replace.revokeAt));
          Node other = replace.node;
          if (other == n) {
            _rejected[replace.statementToken] = '''Don't replace yourself''';
            continue;
          }

          // Replace the other node if allowed.
          if (other == source) {
            // Special case, no paths
            _rejected[replace.statementToken] = 'Attempt to replace your key.';
            continue;
          }

          if (other.revokeAt != null) {
            // In the grand scheme of Oneofus trust, only one key should be able to claim to
            // be the replacement of another, and that should be the responsibilty of
            // web-of-trust equivalence [WotEquivalence], not this class.
            // That said: I don't want to implement revoking at different tokens in Fetcher,
            // and so I do enforce it here.
            _rejected[replace.statementToken] = 'Attempt to replace a replaced key.';
            continue;
          }
          if (other.blocked) {
            // Hmm.. if someone blocks your old key, you should probably be informed about it. 
            // This might be that rejected replace (otherwise, it'd be a rejected block)
            _rejected[replace.statementToken] = 'Attempt to replace a blocked key.';
            continue;
          }

          // replace allowed
          network.putIfAbsent(other.token, () => other);
          final Path newPath = List.of(path)..add(replace);
          other.paths.add(newPath);
          assert(newPath.length == pass + 1); // Just checking
          other.revokeAt = replace.revokeAt;
          await other.trusts; // KLUDGE: Setting revoked at might require re-fetching.
          // Add to queue if not already visited.
          if (!visited.contains(other)) {
            nextLayer.addLast(newPath);
          }
        }
      }
      currentLayer.removeWhere((p) => removeAfterIteration.contains(p));

      // ====== TRUSTS ====== //
      // If pass > degrees, don't add more trusts, just blocks.
      if (pass < degrees) {
        for (Path path in currentLayer) {
          if (!isValidPath(path, network)) continue;
          Node n = path.last.node;
          if (visited.contains(n)) continue;
          visited.add(n);

          for (Trust trust in await n.trusts) {
            final Node other = trust.node;
            if (other == n) {
              _rejected[trust.statementToken] = '''Don't trust yourself.''';
              continue;
            }

            if (path.where((pathEdge) => pathEdge.node == other).isNotEmpty) {
              continue; // Don't let path cycle
            }

            if (other.blocked) {
              _rejected[trust.statementToken] = '''Attempt to trust blocked key.''';
              continue;
            }

            // Trust / further trust other node as necessary, create path, enqueue
            network.putIfAbsent(other.token, () => other);
            final Path newPath = List.of(path)..add(trust);
            other.paths.add(newPath);
            assert(newPath.length == pass + 1); // Just checking

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
      print('.');
      // Remove invalid paths (revoked nodes made edges, node no longer in network (not enough paths)),
      for (Node n in network.values) {
        if (n == source) {
          continue; // Skip this for source.
        }
        n.paths = List.of(n.paths.where((path) => isValidPath(path, network)));
      }
      // Restrict to numPaths
      network.removeWhere((token, node) => (token != source.token) && node.paths.length < numPaths);

      // We're not removing, and so we're done.
      if (network.length == networkSizeBefore) {
        break;
      }
      networkSizeBefore = network.length;
    }
    return network;
  }

  // Walk the path from source to last node.
  // - each node should be in the network.
  // - each edge should have
  //  - statedAt before node was revoked (in case it was revoked)
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

      // validate
      if (fromRevokeAtTime != null && fromRevokeAtTime.isBefore(edge.statedAt)) {
        out = false;
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
