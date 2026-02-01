import 'package:flutter/material.dart';
// import 'package:nerdster/content/content_tree.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/content_view.dart';
import 'package:nerdster/ui/sign_in_screen.dart';
import 'package:nerdster/verify.dart';
import 'package:nerdster/qr_sign_in.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:oneofus_common/trust_statement.dart';

export 'package:nerdster/fire_choice.dart';
export 'package:oneofus_common/jsonish.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final ValueNotifier<bool> isSmall = ValueNotifier<bool>(false);

VoidCallback nerdsterOptimisticConcurrencyFunc = () {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sync Error'),
      content: const Text(
        'Your local data is out of sync with the server (somebody else updated it first).\n\n'
        'We need to reload to get the latest data.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Clear static caches of Statements and Jsonish
            // Because optimistic concurrency failure implies our local history is wrong.
            Jsonish.wipeCache();
            ContentStatement.clearCache();
            TrustStatement.clearCache();

            // Sign out without clearing identity serves as a "soft reload"
            // It destroys the FeedController and its Caches, then lets the user enter again.
            signInState.signOut(clearIdentity: false);
          },
          child: const Text('Reload'),
        ),
      ],
    ),
  );
};

class NerdsterApp extends StatelessWidget {
  const NerdsterApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Merge parameters from both query string and fragment (common in Flutter Web)
    Map<String, String> params = Uri.base.queryParameters;

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
              final bool smallNow = MediaQuery.of(context).size.width < 600;
              if (smallNow != isSmall.value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  isSmall.value = smallNow;
                });
              }

              if (params.containsKey('verifyFullScreen') &&
                  Setting.get<String?>(SettingType.verify).value != null) {
                return const StandaloneVerify();
              } else {
                return ContentView(
                  pov: IdentityKey(signInState.pov),
                  meIdentity: IdentityKey(signInState.identity),
                );
              }
            });
          },
        ));
  }
}
