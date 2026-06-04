import 'package:flutter/material.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/content_view.dart';
import 'package:nerdster/ui/sign_in_widget.dart';
import 'package:nerdster/verify.dart';
import 'package:nerdster/qr_sign_in.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:oneofus_common/trust_statement.dart';

export 'package:nerdster/fire_choice.dart';
export 'package:oneofus_common/jsonish.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final ValueNotifier<bool> isSmall = ValueNotifier<bool>(false);

/// Token of the identity to focus in the graph view on startup (from ?target= URL param).
String? startupTarget;

Future<void> _nerdsterReload() async {
  // Save credentials BEFORE wiping caches — Jsonish.wipeCache() would
  // break identityJson lookup, and signOut() clears the delegate from memory
  // which causes KeyStorageCoordinator to overwrite stored keys with null.
  final savedIdentityJson = signInState.hasIdentity ? signInState.identityJson : null;
  final savedEndpoint = signInState.endpoint;
  final savedDelegateKeyPair = signInState.delegateKeyPair;
  final savedMethod = signInState.signInMethod;

  // Clear static caches of Statements and Jsonish
  // Because optimistic concurrency failure implies our local history is wrong.
  Jsonish.wipeCache();
  ContentStatement.clearCache();
  DismissStatement.clearCache();
  TrustStatement.clearCache();

  // signOut clears the delegate, which triggers FeedController.refresh()
  // via its _onSignInStateChanged listener (delegate changed → refresh).
  // The FeedController itself is NOT destroyed; it stays alive and re-fetches
  // from Firestore now that the static caches are empty.
  signInState.signOut(clearIdentity: false);

  // Re-sign-in immediately with the saved delegate so the user remains
  // fully signed in after the reload, rather than identity-only.
  // Note: signInWithFedKey resets povNotifier to identity (any custom PoV is lost),
  // and triggers a second FeedController.refresh() with the restored delegate.
  if (savedIdentityJson != null && savedDelegateKeyPair != null) {
    final fedKey = FedKey(savedIdentityJson, savedEndpoint);
    await signInState.signInWithFedKey(fedKey, savedDelegateKeyPair, method: savedMethod);
  }
}

/// Called when a background network write fails. Shows a non-dismissible reload
/// dialog — state is inconsistent and there is no safe way to continue.
///
/// Passed to [ChannelFactory.onWriteError]. The infrastructure has already cleared
/// its own caches; [_nerdsterReload] handles app-level cleanup (statement caches,
/// sign-in state) when the user confirms.
Future<void> Function(Object, StackTrace) nerdsterWriteErrorFunc = (_, __) async {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Write Failed'),
      content: const Text(
        'A background write to the server failed.\n\n'
        'The app is in an inconsistent state and must reload.',
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await _nerdsterReload();
          },
          child: const Text('Reload'),
        ),
      ],
    ),
  );
};

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
          onPressed: () async {
            Navigator.of(context).pop();
            await _nerdsterReload();
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
        title: 'Nerdster',
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
  @override
  void initState() {
    super.initState();
    signInState.addListener(_onSignInChanged);
    if (!signInState.hasPov) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDialog());
    }
  }

  @override
  void dispose() {
    signInState.removeListener(_onSignInChanged);
    super.dispose();
  }

  void _onSignInChanged() {
    if (!signInState.hasPov) {
      _maybeShowDialog();
    }
  }

  void _maybeShowDialog() {
    if (!mounted) return;
    showSignInDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: signInState,
      builder: (context, _) {
        if (!signInState.hasPov) {
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
              identity: signInState.hasIdentity ? signInState.identity : null,
            );
          }
        });
      },
    );
  }
}
