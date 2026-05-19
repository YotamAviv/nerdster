class EquivalenceGroup {
  final _EquivalenceCell _root;

  EquivalenceGroup._live(_EquivalenceCell root) : _root = root;

  String get canonical => _root.token;
  Iterable<String> get all => _root._dfsTokens();
  Iterable<String> get donts => _root.donts.map((c) => c.token);

  @override
  String toString() => '$canonical: ${all.toSet()}, -${donts.toSet()}';
}

class Equivalence {
  final Map<String, _EquivalenceCell> _string2cell = {};
  final Set<_EquivalenceCell> _roots = {};

  _EquivalenceCell _createCell(String token) {
    _EquivalenceCell cell = _EquivalenceCell(token);
    _string2cell[token] = cell;
    _roots.add(cell);
    return cell;
  }

  Iterable<EquivalenceGroup> get groups =>
      _roots.map((r) => EquivalenceGroup._live(r));

  bool equate(String equivalent, String canonical, {bool not = false}) {
    _EquivalenceCell canonicalCell = _string2cell[canonical] ?? _createCell(canonical);
    _EquivalenceCell equivalentCell = _string2cell[equivalent] ?? _createCell(equivalent);
    _EquivalenceCell canonicalRoot = canonicalCell.root();
    _EquivalenceCell equivalentRoot = equivalentCell.root();

    if (not) {
      if (equivalentRoot == canonicalRoot) return false;
      canonicalRoot.donts.add(equivalentRoot);
      equivalentRoot.donts.add(canonicalRoot);
      return true;
    }

    if (canonicalRoot == equivalentRoot) {
      // Already in the same EG. Reject only if equivalent is already an ancestor of
      // canonical (inverting the direction).
      _EquivalenceCell x = canonicalCell;
      while (x.parent != null) {
        if (x.parent == equivalentCell) return false;
        x = x.parent!;
      }
      return true;
    }

    bool merged = equivalentRoot.tryMergeInto(canonicalCell);
    if (merged) _roots.remove(equivalentRoot);
    return merged;
  }

  void checkRepInvariant() {
    for (final cell in _string2cell.values) {
      cell.checkRepInvariant();
    }
    for (final root in _roots) {
      assert(root.parent == null);
    }
    for (final cell in _string2cell.values) {
      if (cell.parent == null) assert(_roots.contains(cell));
    }
  }
}

class _EquivalenceCell {
  final String token;
  _EquivalenceCell? parent;
  Set<_EquivalenceCell> children = {};

  /// Only roots maintain donts; donts are always symmetric between roots.
  Set<_EquivalenceCell> donts = {};

  _EquivalenceCell(this.token);

  Iterable<String> _dfsTokens() sync* {
    yield token;
    for (final _EquivalenceCell child in children) {
      yield* child._dfsTokens();
    }
  }

  // Merges this cell's EG into the EG containing newParent. Returns false (without
  // modifying state) if a DONT blocks the merge. Must be called on the EG root.
  bool tryMergeInto(_EquivalenceCell newParent) {
    _EquivalenceCell oldRoot = root();
    _EquivalenceCell parentRoot = newParent.root();
    if (parentRoot.donts.contains(oldRoot)) {
      assert(oldRoot.donts.contains(parentRoot));
      return false;
    }
    assert(!oldRoot.donts.contains(parentRoot));
    parentRoot.donts.addAll(oldRoot.donts);
    for (final _EquivalenceCell o in oldRoot.donts) {
      o.donts.add(parentRoot);
      o.donts.remove(oldRoot);
    }
    oldRoot.donts.clear();
    parent = newParent;
    newParent.children.add(this);
    return true;
  }

  _EquivalenceCell root() {
    _EquivalenceCell out = this;
    while (out.parent != null) {
      out = out.parent!;
    }
    return out;
  }

  void checkRepInvariant() {
    if (parent != null) {
      assert(donts.isEmpty);
      assert(parent!.children.contains(this));
    } else {
      for (final _EquivalenceCell other in donts) {
        assert(other.parent == null, token);
        assert(other.donts.contains(this));
      }
      assert(donts.map((c) => c.token).toSet().length == donts.length);
    }
    for (final _EquivalenceCell child in children) {
      assert(child.parent == this);
    }
  }
}
