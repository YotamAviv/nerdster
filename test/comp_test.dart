import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nerdster/comp.dart';
import 'package:test/test.dart';

Random random = Random();
bool invalidProcessHappened = false;

// Summer carries a value, n.
// Summer computes the sum of itself and its supporters (which it depends on).
class Summer with Comp, ChangeNotifier {
  final String name;
  final int delay;

  int _n = 0;
  int _result = 0;

  Summer(this.name, this.delay);

  void addSummer(Summer summer) {
    super.addSupporter(summer);
    summer.addListener(setDirty);
  }

  @override
  void setDirty() {
    if (!ready) {
      // Uncommenting the return below makes the async tests fails.
      // I'd like to understand why better. I suspect that anything goes during async gaps and that
      // I may have gone dirty->ready->dirty.. or something like that.
      // Until I do, keep this same patter in the code:
      // => setDirty means setDirty and notify observers every time!

      // return;
    }
    super.setDirty();
    notifyListeners();
  }

  int get n => _n;
  set n(int n) {
    _n = n;

    if (!ready) {
      return;
    }
    setDirty();
    notifyListeners();
  }

  @override
  Future<void> process() async {
    throwIfSupportersNotReady();

    await Future.delayed(Duration(microseconds: delay * 100));

    _result = _n;
    for (Summer summer in supporters.cast<Summer>()) {
      if (!summer.ready) {
        assert(invalidProcess);
        invalidProcessHappened = true;
        return;
      }
      _result += summer.result;
    }
  }

  int get result {
    assert(ready);
    return _result;
  }

  @override
  String toString() => name;
}

class Changer {
  final Summer s1;
  final Summer s2;
  Changer(this.s1, this.s2);
  Future make() {
    Completer<void> completer = Completer<void>();
    Future.delayed(Duration(microseconds: random.nextInt(10))).then((_) {
      s1.n = s1.n - 1;
      s2.n = s2.n + 1;
    }).then((_) {
      Future.delayed(Duration(microseconds: random.nextInt(10)));
    }).then((_) {
      s1.n = s1.n - 1;
      s2.n = s2.n + 1;
    }).then((_) => completer.complete());
    return completer.future;
  }
}

class Checker {
  final Summer sRandomMiddle;
  final Summer sTop;
  Checker(this.sRandomMiddle, this.sTop);
  Future make() {
    Completer<void> completer = Completer<void>();
    Future.delayed(Duration(microseconds: random.nextInt(10))).then((_) {
      Comp.waitOnComps([sRandomMiddle, sTop]).then((_) {
        int rRandomMiddle = sRandomMiddle.result;
        int rTop = sTop.result;
        expect(rTop, 99 * 50 + 9 * 5);
        // print('$rRandomMiddle, $rTop');
      }).then((_) => completer.complete());
    });
    return completer.future;
  }
}

class BrokenSummer extends Summer {
  BrokenSummer(super.name, super.delay);
  @override
  Future<void> process() async {
    await Future.delayed(Duration(microseconds: delay * random.nextInt(100)));
    throw Exception('broken');
  }
}

void main() async {
  setUp(() async {});

  test('base', () async {
    Summer a = Summer('a', 3);
    a.n = 1;
    Summer b = Summer('b', 8);
    b.n = 2;
    Summer c = Summer('c', 4);
    c.n = 3;
    c.addSummer(a);
    c.addSummer(b);

    await c.waitUntilReady();
    expect(c.result, 6);
    b.n = 12;
    expect(b.ready, false);
    expect(c.ready, false);
    await c.waitUntilReady();
    expect(c.ready, true);
    expect(a.ready, true);
    expect(b.ready, true);
    expect(c.result, 16);

    Summer d = Summer('d', 1);
    d.addSummer(c);
    d.addSummer(b);
    d.n = 1;
    await d.waitUntilReady();
    expect(d.result, 29);

    a.n = 2;
    await d.waitUntilReady();
    expect(d.result, 30);
  });

  test('async, delays..', () async {
    // Create 111 that feed up to top (100 at bottom, 10 next layer, 1 at top)
    List<Summer> bottom = <Summer>[];
    for (int i = 0; i < 100; i++) {
      bottom.add(Summer('bottom-$i', random.nextInt(50)));
    }
    List<Summer> middle = <Summer>[];
    for (int i = 0; i < 10; i++) {
      Summer s = Summer('middle-$i', random.nextInt(50));
      middle.add(s);
      for (int j = 0; j < 10; j++) {
        s.addSummer(bottom[i * 10 + j]);
      }
    }
    Summer top = Summer('top', random.nextInt(50));
    for (int i = 0; i < 10; i++) {
      top.addSummer(middle[i]);
    }
    await top.waitUntilReady();
    expect(top.result, 0);

    // Set them to values 0-99 and 0-9.
    for (int i = 0; i < 100; i++) {
      bottom[i].n = i;
    }
    for (int i = 0; i < 10; i++) {
      middle[i].n = i;
    }
    await top.waitUntilReady();
    expect(top.result, 99 * 50 + 9 * 5);

    // Start up some stocastic Changers and Checkers..
    // Let them finish.
    // Make sure that at least something experienced 'invalidProcess' (where
    // it becomes dirty during processing).
    // Changers add and remove 1, and so top should remain steady, and
    // that's tested by the Checkers.
    List<Future> futures = <Future>[];
    for (int i = 0; i < 100; i++) {
      int i = random.nextInt(100);
      int j = random.nextInt(10);
      futures.add(Changer(bottom[i], middle[j]).make());
      int k = random.nextInt(10);
      futures.add(Checker(middle[k], top).make());
    }
    await Future.wait(futures);
    expect(invalidProcessHappened, true);

    await top.waitUntilReady();
    expect(top.result, 99 * 50 + 9 * 5);
  });

  test('exception', () async {
    Summer broken = BrokenSummer('broken', 5);
    Summer summer = Summer('summer2', 5);
    summer.addSummer(broken);

    bool caught = false;
    try {
      await Comp.waitOnComps([summer]);
      fail('expected exception');
    } catch (e) {
      expect(e.toString().contains('broken'), true);
      caught = true;
    }
    expect(caught, true);
    expect(summer.ready, false);
    expect(broken.ready, false);
  });

  test('exception, 2 summers waiting', () async {
    Summer bs = BrokenSummer('broken', 5);
    Summer summer1 = Summer('summer1', 5);
    Summer summer2 = Summer('summer2', 5);
    summer1.addSummer(bs);
    summer2.addSummer(bs);

    bool caught = false;
    try {
      await Comp.waitOnComps([summer1, summer2]);
      fail('expected exception');
    } catch (e) {
      expect(e.toString().contains('broken'), true);
      caught = true;
    }
    expect(caught, true);
    expect(summer1.ready, false);
    expect(summer2.ready, false);
    expect(bs.ready, false);
  });

  // 2 waiters exercises a different code path as the first waiter initiates the call to process(),
  // but the second waiter is waiting on ready state.
  test('exceptions caught', () async {
    Summer bs = BrokenSummer('a', 5);
    ExceptionExpecter ee1 = ExceptionExpecter(bs, 'ee1');
    ExceptionExpecter ee2 = ExceptionExpecter(bs, 'ee2');

    try {
      await Comp.waitOnComps([ee1, ee2]);
    } catch (e) {
      fail('Unexpected: $e');
    }
    expect(ee1.caught != null, true);
    expect(ee1.ready, true);
    expect(ee2.caught != null, true);
    expect(ee2.ready, true);
    expect(bs.ready, false);
  });
}

class ExceptionExpecter extends Comp {
  final Comp comp;
  final String name;
  Object? caught;

  ExceptionExpecter(this.comp, this.name);

  @override
  Future<void> process() async {
    try {
      await comp.waitUntilReady();
      fail('expected exception');
    } catch (e) {
      caught = e;
    }
    expect(caught != null, true);
  }
}
