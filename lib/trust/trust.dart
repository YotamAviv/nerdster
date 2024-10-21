/// Capture the essence of the core algorithm.
/// [Node] used to be cleaner but now carries state for the [Trust1] algorithm.
///
/// The worst malicious actor will try to game our algorithm and won't fear making
/// many false statements.
/// Consider our algorithm from his point of view.
///
/// Different approaches:
/// - Try to find a solution (accepted/rejected nodes) with the fewest conflicts:
/// Cons:
/// - exponential. 2**100 is very large
///
/// Rely on notifications and try to do something reasonable and cautious.
///
/// Equate / (dontEquate):
/// - Equate is simple. Only you would say that your old key is an equivalent of your
/// key, as that gives that other key your validity.
/// And so it's like a regular Edge:from->to (Edge:canonical(you)->equivalent(otherKey)).
/// - What's the use-case for dontEquate?
/// A key signed off power to another key.
/// That key doesn't have a problem with that, but someone else does?
/// Decided: No dontEquate.
/// - If you said equate by accident, then you can delete your equate statement.
/// - If your key was compromised and is now in a possession of a bad actor who has chosen to
///   use equate to make out edges from his thieved key, then he could have easily just made
///   trust edges.
///
/// CONSIDER: output of algorithm to include:
/// - nodes not in the network, perhaps trusted and also blocked.
///   (for to show rejected statements)
/// - notifications
///   (just rejected statements, I think)
/// - rejected statements
/// - paths
/// Ran deferring with the hope that [NerdTree] can show rejected statements on its own easily enough.
library;

typedef Path = List<Trust>;

/// Node: Instances carry state (inNetwork, revokeAt, paths) for use by the algorihtm (Trust1),
/// and so we must reliably clear that before computations.
abstract class Node {
  final String token;
  Node(this.token);

  bool _blocked = false;
  List<Path> paths = [];

  // ignore: unnecessary_getters_setters
  bool get blocked => _blocked;
  set blocked(bool b) {
    _blocked = b;
  }

  String? get revokeAt;
  set revokeAt(String? revokeAt);
  DateTime? get revokeAtTime;

  Future<Iterable<Trust>> get trusts; // newest to oldest
  Future<Iterable<Replace>> get replaces; // newest to oldest
  Future<Iterable<Block>> get blocks; // newest to oldest
}

abstract class TrustAlgorithm {
  Future<Map<String, Node>> process(Node node, {int numPaths = 1});
}

class Trust {
  final String statementToken;
  final DateTime statedAt;
  final Node node;
  Trust(this.node, this.statedAt, this.statementToken);
}

class Replace extends Trust {
  final String revokeAt;
  Replace(super.node, super.statedAt, this.revokeAt, super.statementToken);
}

class Block {
  final String statementToken;
  final DateTime statedAt;
  final Node node;
  Block(this.node, this.statedAt, this.statementToken);
}
