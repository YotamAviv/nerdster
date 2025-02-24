import 'package:nerdster/equivalence/eg.dart';
import 'package:nerdster/equivalence/equate_statement.dart';

/// Concerns (resolved):
/// - (Do we reject DONTs? We do!
/// In case a DONT is rejected (Already have: A <= B, receive A !<= B.)
/// Should we note the DONT and respect it moving foward?)
/// - (I had this lingering concern that we'd reject A is canonical of equivalent B (A <= B)
/// in case we already had B <= A either directly or indirectly (B <= X, X <= A) but that
/// we shouldn't or that we should at least treat it as the opposite.
/// It should be rejected. The code is good. If we're rejecting it, then it's either because
/// of a DONT or because they're already in the same EG.)
class Equivalence {
  final Map<String, _EquivalenceCell> _string2cell = <String, _EquivalenceCell>{};

  _EquivalenceCell _createCell(String element) {
    _EquivalenceCell cell = _EquivalenceCell(element);
    _string2cell[element] = cell;
    return cell;
  }

  // For testing only, not efficient.
  // (If/when we want efficiency for something like this, we can manage children pointers.)
  Set<EquivalenceGroup> createGroups() {
    Map<String, EquivalenceGroup> canonical2eg = <String, EquivalenceGroup>{};
    for (MapEntry<String, _EquivalenceCell> entry in _string2cell.entries) {
      _EquivalenceCell root = entry.value.root();
      String canonical = root.token;
      Set<String> donts = Set.from(root.donts.map((cell) => cell.token));
      canonical2eg.putIfAbsent(canonical, () => EquivalenceGroup(canonical, {}, donts));
      canonical2eg[canonical]!.all.add(entry.value.token);
    }
    return canonical2eg.values.toSet();
  }

  bool process(final EquateStatement es) {
    final String canonical = es.canonical;
    final String equivalent = es.equivalent;
    _EquivalenceCell? canonicalCell = _string2cell[canonical];
    _EquivalenceCell? canonicalRoot = canonicalCell?.root();
    _EquivalenceCell? equivalentCell = _string2cell[equivalent];
    _EquivalenceCell? equivalentRoot = equivalentCell?.root();

    if (es.dont) {
      canonicalCell ??= _createCell(canonical);
      canonicalRoot ??= canonicalCell.root();
      equivalentCell ??= _createCell(equivalent);
      equivalentRoot ??= equivalentCell.root();
      if (equivalentRoot == canonicalRoot) {
        return false;
      } else {
        canonicalRoot.donts.add(equivalentRoot);
        equivalentRoot.donts.add(canonicalRoot);
        return true;
      }
    }

    // The new statement says: newCanonical <= newEquivalent.
    // The natural desire is to make newEquivalent a child of newCanonical.
    // But we might already have these in our tree, might have NOTs, and so there may be conflicts.
    if (canonicalCell != null && equivalentCell != null) {
      // both newCanonical and newEquivalent and are already known
      if (canonicalRoot == equivalentRoot) {
        // They're already in the same EG, and they'll stay in the same EG.
        // (This EG may grow, but it won't be split up by NOTs and I don't think that it matters how the tree is organized.)
        // The only thing that might change anything that matters is the choice of root.
        // If newCanonical is already the root, then it stays there; if it isn't then somebody already gave it a different canonical.
        // So: Do nothing.
        // Climb up tree just to check if equivalent is canonical of canonical.
        _EquivalenceCell x = canonicalCell;
        while (x.parent != null) {
          if (x.parent!.token == equivalent) {
            return false;
          }
          x = x.parent!;
        }
        return true;
      } else {
        // They're in different EGs.
        // Join the 2 EGs unless a NOT prohibits it.
        // Make the parent of the root of newEquivalent be newCanonical.
        return equivalentRoot!.checkAndSetParent(canonicalCell);
      }
    } else if (equivalentCell != null) {
      // Only newEquivalent is already known:
      // Make newCanonical the new root of that existing EG.
      canonicalCell = _createCell(canonical);
      bool noNotIssues = equivalentRoot!.checkAndSetParent(canonicalCell);
      assert(noNotIssues);
      return true;
    } else if (canonicalCell != null) {
      // only newCanonical is already known.
      // add newEquivalent as a child of newCanonical.
      equivalentCell = _createCell(equivalent);
      bool noNotIssues = equivalentCell.checkAndSetParent(canonicalCell);
      assert(noNotIssues);
      return true;
    } else {
      canonicalCell = _createCell(canonical);
      equivalentCell = _createCell(equivalent);
      bool noNotIssues = equivalentCell.checkAndSetParent(canonicalCell);
      assert(noNotIssues);
      return true;
    }
  }

  void checkRepInvariant() {
    _string2cell.forEach((key, value) {
      value.checkRepInvariant();
    });
  }
}

// TODO: override == and hashCode as we're keeping these in sets. Add test, too.
class _EquivalenceCell {
  String token;
  _EquivalenceCell? parent;
  /// Only EG roots maintain DONTs.
  /// We want to facilitate:
  /// - checking if a DONT exists
  /// - updating our data when a parent cell gets a new parent.
  /// Note: A DONT with 2 roots will never be collapsed into one, as the DONT prevents that; it'd be a contradiction.
  /// But 2 DONTs might become the same DONT as roots are collapsed into one EG.
  /// Note: DONTs can exist ahead of equivalencies. That is we could process X != Y and only later process X <= Y.
  /// And so we might end up creating EquivalenceCell instances that have no parents or children, just DONT relationships.
  /// This also means that if an EquivalenceCell does DONT exist for a string, then no related DONTs exist either.
  Set<_EquivalenceCell> donts = {};

  _EquivalenceCell(this.token);

  // The context of our usage makes it so that we oncly call this when switching to a new EG.
  // We never switch to an existing node in our current EG.
  // The roots contain the DONTs.
  // When 2 EGs merge, we:
  // - union DONTs from child up to parent
  // - update DONTs at EC's of child to be parent (unless parent was already there).
  // CODE: add a check invariant
  // - only roots have DONTs.
  // - DONTs are symmetric.
  // 
  // It looks like, and I'll go go under the assumption, that it returns false when the
  // set is rejected. Maybe verify.
  bool checkAndSetParent(_EquivalenceCell newParent) {
    // Find our current root
    _EquivalenceCell oldRoot = root();

    // Find parent's current root
    _EquivalenceCell parentRoot = newParent.root();

    // Check for DONTs
    if (parentRoot.donts.contains(oldRoot)) {
      assert(oldRoot.donts.contains(parentRoot));
      // print('prevented by DONT');
      return false;
    }
    assert(!oldRoot.donts.contains(parentRoot));

    // Set the new parent and update DONTs
    parentRoot.donts.addAll(oldRoot.donts);
    for (_EquivalenceCell o in oldRoot.donts) {
      o.donts.add(parentRoot);
      o.donts.remove(this);
    }
    donts.clear();
    parent = newParent;

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
    // Only roots have DONTs
    if (parent != null) {
      assert(donts.isEmpty);
    }

    // DONTs are stored symmetricly.
    if (parent == null) {
      for (_EquivalenceCell otherRoot in donts) {
        assert(otherRoot.parent == null, token);
        assert(otherRoot.donts.contains(this));
      }
    }

    // No duplicate DONTs
    Set<String> strings = {};
    if (parent == null) {
      for (_EquivalenceCell otherRoot in donts) {
        strings.add(otherRoot.token);
      }
    }
    assert(strings.length == donts.length);
  }
}
