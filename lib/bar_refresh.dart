import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

import 'oneofus/measure.dart';

class BarRefresh extends StatefulWidget {
  static final Measure measure = Measure('refresh');

  const BarRefresh({
    super.key,
  });

  // TODO: context not nullable
  static Future<void> refresh(BuildContext? context) async {
    if (!measure.isRunning) {
      try {
        Measure.reset();
        measure.start();
        // This could probably be captured in an Observable Comp instance
        // OPTIONAL: (maybe add to Dev menu): Jsonish.wipeCache();
        Fetcher.clear();
        clearDistincterCache(); // redundant?
        oneofusNet.listen();

        await Comp.waitOnComps([contentBase, keyLabels]);
      } catch (e, stack) {
        if (context != null) await alert(e.toString(), stack.toString(), ['Okay'], context);
      } finally {
        measure.stop();
        Measure.dump();
      }
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
          BarRefresh.refresh(context);
        });
  }
}
