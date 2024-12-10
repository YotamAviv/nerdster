import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

class BarRefresh extends StatefulWidget {
  static final ValueNotifier<Stopwatch?> stopwatch = ValueNotifier<Stopwatch?>(null);

  const BarRefresh({
    super.key,
  });

  static elapsed(String s) {
    if (b(stopwatch.value)) {
      print('$s: elapsed: ${BarRefresh.stopwatch.value!.elapsed}');
    }
  }

  static Future<void> refresh() async {
    // - The state is BarRefresh.stopwatch
    // - ignore the click if we're already refreshing
    if (!b(stopwatch.value)) {
      stopwatch.value = Stopwatch();
      stopwatch.value!.start();

      // This could probably be captured in an Observable Comp instance      
      Fetcher.clear();
      Jsonish.wipeCache(); // TEMP
      clearDistinct(); // redundant
      oneofusNet.listen();
      
      await Comp.waitOnComps([contentBase, keyLabels]);
      print('Refresh took: ${stopwatch.value!.elapsed}');
      stopwatch.value!.stop();
      stopwatch.value = null;
      Fetcher.measure.dump(); // TEMP
    }
  }

  @override
  State<StatefulWidget> createState() => _BarRefreshState();
}

class _BarRefreshState extends State<BarRefresh> {
  @override
  void initState() {
    super.initState();
    BarRefresh.stopwatch.addListener(listener);
  }

  @override
  void dispose() {
    BarRefresh.stopwatch.removeListener(listener);
    super.dispose();
  }

  void listener() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    IconData icon = !b(BarRefresh.stopwatch.value) ? Icons.refresh : Icons.rotate_right_outlined;
    return IconButton(
        icon: Icon(icon),
        color: linkColor,
        tooltip: 'Refresh',
        // A little sloppy..
        // - The state is BarRefresh.stopwatch
        // - just ignore the click if we're already refreshing
        onPressed: () {
          BarRefresh.refresh();
        });
  }
}
