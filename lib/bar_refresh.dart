import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

// (This used to be a StatefulWidget before progress dialog)
class BarRefresh extends StatelessWidget {
  const BarRefresh({
    super.key,
  });

  static Future<void> refresh(BuildContext context) async {
    await progress.make(() {
      Fetcher.clear();
      oneofusNet.listen();
    }, context);
  }

 @override
  Widget build(BuildContext context) {
    return IconButton(
        icon: Icon(Icons.refresh),
        color: linkColor,
        tooltip: 'Refresh',
        onPressed: () {
          BarRefresh.refresh(context);
        });
  }
}
