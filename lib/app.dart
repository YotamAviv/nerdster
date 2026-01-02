import 'package:flutter/material.dart';
import 'package:nerdster/content/content_tree.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/fancy_shadow_view.dart';
import 'package:nerdster/v2/graph_demo.dart';
import 'package:nerdster/v2/nerdy_content_view.dart';
import 'package:nerdster/verify.dart';

export 'package:nerdster/fire_choice.dart';
export 'package:nerdster/oneofus/jsonish.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// This doesn't work. [ContentTree] sets this using [BuildContext].
// On my Pixel 6a, size is (374.2, 713.1).
ValueNotifier<bool> isSmall = ValueNotifier<bool>(true);

class NerdsterApp extends StatelessWidget {
  const NerdsterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: ListenableBuilder(
        listenable: signInState,
        builder: (context, _) {
          final path = Uri.base.path;
          final povToken = signInState.pov;

          if (path == '/m' || path.startsWith('/m/') || path == '/m.html' || path == '/v2/phone') {
            return FancyShadowView(povToken: povToken);
          } else if (path == '/v2/graph') {
            return TrustGraphVisualizerLoader(povToken: povToken);
          } else if (path == '/legacy/content') {
            return ContentTree();
          } else if (path == '/legacy/net') {
            return NetTreeView(NetTreeView.makeRoot());
          } else if (Uri.base.queryParameters.containsKey('verifyFullScreen') &&
              b(Setting.get(SettingType.verify).value)) {
            return const StandaloneVerify();
          } else {
            // Default to NerdyContentView
            return NerdyContentView(povToken: povToken);
          }
        },
      ),
    );
  }
}
