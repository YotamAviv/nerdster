import 'package:flutter/material.dart';
// import 'package:nerdster/content/content_tree.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/content_view.dart';
import 'package:nerdster/ui/sign_in_widget.dart';
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
        home: _AppHome(params: params));
  }
}

/// Home widget that auto-shows the sign-in dialog as an overlay whenever
/// there is no identity. The dialog is shown on the Navigator stack so it
/// survives route changes (e.g. the underlying route switching from the
/// placeholder to ContentView after sign-in).
class _AppHome extends StatefulWidget {
  final Map<String, String> params;
  const _AppHome({required this.params});

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> {
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    signInState.addListener(_onSignInChanged);
    if (!signInState.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDialog());
    }
  }

  @override
  void dispose() {
    signInState.removeListener(_onSignInChanged);
    super.dispose();
  }

  void _onSignInChanged() {
    if (!signInState.isSignedIn) {
      _maybeShowDialog();
    }
  }

  void _maybeShowDialog() {
    if (_dialogShowing || !mounted) return;
    _dialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        child: SignInDialog(),
      ),
    ).then((_) {
      _dialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: signInState,
      builder: (context, _) {
        if (!signInState.isSignedIn) {
          // Placeholder behind the sign-in dialog overlay.
          return const Scaffold(body: SizedBox.shrink());
        }

        return Builder(builder: (context) {
          final bool smallNow = MediaQuery.of(context).size.width < 600;
          if (smallNow != isSmall.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              isSmall.value = smallNow;
            });
          }

          if (widget.params.containsKey('verifyFullScreen') &&
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
    );
  }
}
