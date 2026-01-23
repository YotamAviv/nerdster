import 'package:flutter/material.dart';
// import 'package:nerdster/content/content_tree.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/content_view.dart';
import 'package:nerdster/v2/phone_view.dart';
import 'package:nerdster/v2/sign_in_screen.dart';
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: ListenableBuilder(
          listenable: signInState,
          builder: (context, _) {
            if (!signInState.isSignedIn) {
              return const SignInScreen();
            }

            return Builder(builder: (context) {
                // final path = Uri.base.path; 
                final String pov = signInState.pov;

                final bool smallNow = MediaQuery.of(context).size.width < 600;
                if (smallNow != isSmall.value) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    isSmall.value = smallNow;
                  });
                }

                if (params.containsKey('verifyFullScreen') &&
                    b(Setting.get(SettingType.verify).value)) {
                  return const StandaloneVerify();
                } else {
                  // Default to ContentView (now responsive)
                  if (smallNow) {
                     return PhoneView(meIdentity: IdentityKey(signInState.identity));
                  } else {
                    return ContentView(
                      pov: IdentityKey(pov),
                      meIdentity: IdentityKey(signInState.identity),
                    );
                  }
                }
              });
          },
        ));
  }
}
