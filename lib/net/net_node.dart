import 'dart:collection';

import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/merger.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/singletons.dart';

/// Stricly canonical.
/// Used in [NetTreeNode], tests, possibly redundant.
///
/// These are different form the [OneofusNet] [_FetcherNodes], which are not strictly cannonical,
/// have trust edges for 'replace', maybe more..
class NetNode {
  static final Map<String, NetNode> _all = <String, NetNode>{};

  static void clear() {
    _all.clear();
  }

  final String token;
  Set<NetNode>? _children;

  factory NetNode(token) {
    _all.putIfAbsent(token, () => NetNode._internal(token));
    return _all[token]!;
  }

  NetNode._internal(this.token);

  Iterable<NetNode> get children {
    assert(oneofusEquiv.ready);
    if (_children != null) return _children!;
    _children = SplayTreeSet<NetNode>(
        (n, o) => oneofusNet.getPosition(n.token)!.compareTo(oneofusNet.getPosition(o.token)!));
    Iterable<Iterable<TrustStatement>> iiStatements = oneofusEquiv.getEquivalents(token).map((t) =>
        distinct(Fetcher(t, kOneofusDomain)
                .statements
                .where((s) => !NotificationsMenu.rejected.containsKey(s.token)))
            .cast<TrustStatement>()
            .where((s) => s.verb == TrustVerb.trust));
    Merger merger = Merger(iiStatements);
    Iterable<TrustStatement> dis =
        distinct(merger.cast(), transformer: oneofusEquiv.getCanonical).cast<TrustStatement>();
    for (TrustStatement statement in dis) {
      assert(oneofusNet.network.containsKey(statement.iToken));
      if (!oneofusNet.network.containsKey(statement.subjectToken)) continue;
      NetNode child = NetNode(oneofusEquiv.getCanonical(statement.subjectToken));
      if (!_children!.contains(child)) {
        _children!.add(child);
      }
    }
    return _children!;
  }
}
