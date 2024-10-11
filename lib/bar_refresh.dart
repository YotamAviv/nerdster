import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/net/oneofus_equiv.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in_state.dart';

class BarRefresh extends StatefulWidget {
  static Stopwatch? stopwatch;

  const BarRefresh({
    super.key,
  });

  static elapsed(String s) {
    if (b(stopwatch)) {
      print('$s: elapsed: ${BarRefresh.stopwatch!.elapsed}');
    }
  }

  @override
  State<StatefulWidget> createState() => _BarRefreshState();
}

class _BarRefreshState extends State<BarRefresh> {
  @override
  Widget build(BuildContext context) {
    IconData icon = !b(BarRefresh.stopwatch) ? Icons.refresh : Icons.rotate_right_outlined;
    return IconButton(
        icon: Icon(icon),
        tooltip: 'Refresh',
        // A little sloppy..
        // - The state is BarRefresh.stopwatch
        // - just ignore the click if we're already refreshing
        onPressed: () async {
          if (!b(BarRefresh.stopwatch)) {
            BarRefresh.stopwatch = Stopwatch();
            BarRefresh.stopwatch!.start();
            SignInState().center = SignInState().center;
            setState(() {});
            await Comp.waitOnComps([OneofusEquiv(), FollowNet()]);
            print('Refresh took: ${BarRefresh.stopwatch!.elapsed}');
            BarRefresh.stopwatch!.stop();
            BarRefresh.stopwatch = null;
            setState(() {});
          }
        });
  }
}
