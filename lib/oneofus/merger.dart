import 'statement.dart';
import 'util.dart';

/// Merge statement streams
/// Probably Fetcher.statements, probably:
/// - ContentBase/FollowNet for different delegates of single oneofus,
/// - NetNode for equivs, 
class Merger extends Iterable implements Iterator {
  late final List<Iterator<Statement>> _iters;
  Statement? _next;

  Merger(Iterable<Iterable<Statement>> iterables)
      : _iters = List.of(iterables.map((f) => f.iterator).where((i) => i.moveNext()));

  @override
  get current => _next;

  @override
  bool moveNext() {
    _next = null;
    if (_iters.isNotEmpty) {
      Iterator<Statement>? mostRecent;
      for (Iterator<Statement> i in _iters) {
        if (mostRecent == null || i.current.time.isAfter(mostRecent.current.time)) {
          mostRecent = i;
        }
      }
      _next = mostRecent!.current;
      if (!mostRecent.moveNext()) {
        _iters.remove(mostRecent);
      }
    }
    return b(_next);
  }

  @override
  Iterator get iterator => this;
}
