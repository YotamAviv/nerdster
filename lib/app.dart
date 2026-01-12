import 'package:flutter/material.dart';
import 'package:nerdster/credentials_display.dart';
// import 'package:nerdster/content/content_tree.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/content_view.dart';
import 'package:nerdster/v2/phone_view.dart';
import 'package:nerdster/verify.dart';
import 'package:nerdster/qr_sign_in.dart';

export 'package:nerdster/fire_choice.dart';
export 'package:nerdster/oneofus/jsonish.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

ValueNotifier<bool> isSmall = ValueNotifier<bool>(false);

class NerdsterApp extends StatelessWidget {
  const NerdsterApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Merge parameters from both query string and fragment (common in Flutter Web)
    Map<String, String> params = collectQueryParameters();

    // Check for qrSignIn query parameter on startup
    if (params.containsKey('qrSignIn') && params['qrSignIn'] == 'true') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          qrSignIn(context);
        }
      });
    }

    return MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        home: CredentialsWatcher(
          child: ListenableBuilder(
            listenable: signInState,
            builder: (context, _) {
              final path = Uri.base.path;
              final pov = signInState.pov;

              final bool smallNow = MediaQuery.of(context).size.width < 600;
              if (smallNow != isSmall.value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  isSmall.value = smallNow;
                });
              }

              if (path == '/m' ||
                  path.startsWith('/m/') ||
                  path == '/m.html' ||
                  path == '/v2/phone') {
                return PhoneView(povIdentity: pov != null ? IdentityKey(pov) : null);
              } else if (params.containsKey('verifyFullScreen') &&
                  b(Setting.get(SettingType.verify).value)) {
                return const StandaloneVerify();
              } else {
                // Default to ContentView
                return ContentView(pov: pov != null ? IdentityKey(pov) : null);
              }
            },
          ),
        ));
  }
}
