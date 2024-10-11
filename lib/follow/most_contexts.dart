class MostContexts {
  final Map<String, int> _x2count = <String, int>{};

  void clear() {
    _x2count.clear();
  }

  void process(xs) {
    for (String x in xs) {
      if (!_x2count.containsKey(x)) {
        _x2count[x] = 0;
      }
      _x2count[x] = _x2count[x]! + 1;
    }
  }

  Iterable<String> most() {
    List<MapEntry<String, int>> sorted = _x2count.entries.toList()
      ..sort((e1, e2) => e2.value.compareTo(e1.value));
    return sorted.map((e) => e.key);
  }
}