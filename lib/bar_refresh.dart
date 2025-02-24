import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/measure.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

class BarRefresh extends StatefulWidget {
  static final Measure measure = Measure('refresh');

  const BarRefresh({
    super.key,
  });


  static Future<void> refresh() async {
    if (!measure.isRunning) {
      Measure.reset();
      measure.start();
      // This could probably be captured in an Observable Comp instance
      // OPTIONAL: (maybe add to Dev menu): Jsonish.wipeCache();
      Fetcher.clear();
      clearDistinct(); // redundant
      oneofusNet.listen();
      
      await Comp.waitOnComps([contentBase, keyLabels]);
      measure.stop();
      Measure.dump();
    }
  }

  @override
  State<StatefulWidget> createState() => _BarRefreshState();
}

class _BarRefreshState extends State<BarRefresh> {
  @override
  void initState() {
    super.initState();
    BarRefresh.measure.addListener(listener);
  }

  @override
  void dispose() {
    BarRefresh.measure.removeListener(listener);
    super.dispose();
  }

  void listener() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    IconData icon = !BarRefresh.measure.isRunning ? Icons.refresh : Icons.rotate_right_outlined;
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
