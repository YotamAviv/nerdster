class EquivalenceGroup {
  String canonical;
  Set<String> all = <String>{}; // both nominal and equivalents
  Set<String> donts;

  EquivalenceGroup(this.canonical, Set<String> equivalents, this.donts) {
    all.add(canonical);
    all.addAll(equivalents);
  }

  @override
  String toString() {
    return '$canonical: $all, -$donts';
  }

  @override
  bool operator ==(other) {
    if (other is! EquivalenceGroup) {
      return false;
    }
    EquivalenceGroup o = other;
    return o.toString() == toString();
  }

  @override
  int get hashCode {
    return toString().hashCode;
  }
}
