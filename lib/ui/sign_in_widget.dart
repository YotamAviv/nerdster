import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/key_storage_coordinator.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster_common/ui/json_interpreter.dart';
import 'package:nerdster/paste_sign_in.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/sign_in_session.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/key_icon.dart';
import 'package:nerdster/ui/util/my_checkbox.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/ui/json_qr_display.dart';
import 'package:nerdster_common/ui/sign_in_dialog.dart';

/// Hardcoded developer identity public key for "Use developer's Point of View" sign-in.
/// Lets Apple App Store reviewers use the app without needing the ONE-OF-US.NET identity app.
/// Signs in as Yotam Aviv's public identity key — read-only, no delegate key.
const Map<String, dynamic> _kDevIdentityKey = {
  'crv': 'Ed25519',
  'kty': 'OKP',
  'x': 'Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo',
};

/// Key icon convention (see key_icon.dart for full details):
///   - Green outlined  = identity key (Nerdster never holds the private identity key)
///   - Blue filled     = delegate key, owned (private key present on device)
///   - Blue outlined   = delegate key, not owned / missing

/// Set to true (via ?forceIphone=true URL param) to simulate iOS sign-in UI on non-iOS platforms.
final bool forceIphone = kIsWeb && Uri.base.queryParameters['forceIphone'] == 'true';

Future<void> _signInAsDev(BuildContext context) async {
  final key = await crypto.parsePublicKey(_kDevIdentityKey);
  final Json keyJson = await key.json;
  FedKey(keyJson, kNativeEndpoint);
  signInState.pov = getToken(keyJson);
  if (context.mounted) Navigator.pop(context);
}

SignInConfig buildNerdsterSignInConfig() {
  return SignInConfig(
    sessionFactory: createNerdsterSignInSession,
    firestore: FireFactory.find(kNerdsterDomain),
    onData: nerdsterOnSessionData,
    stateNotifier: signInState,
    hasIdentity: () => signInState.hasIdentity,
    hasDelegate: () => signInState.delegate != null,
    identityJson: () => signInState.hasIdentity ? signInState.identityJson : null,
    delegatePublicKeyJson: () => signInState.delegatePublicKeyJson,
    onSignOut: () => signInState.signOut(clearIdentity: false),
    onForgetIdentity: () => signInState.signOut(clearIdentity: true),
    onPasteSignIn: pasteSignIn,
    showPasteInitially: Setting.get<bool>(SettingType.dev).value,
    devSignInLabel: 'Enter the Nerdster',
    devSignInLeading: Image.asset('assets/images/nerd.png', width: 24, height: 24),
    onDevSignIn: _signInAsDev,
    onKeyTap: (context, label, json) => showDialog(
      context: context,
      builder: (_) {
        final double width = MediaQuery.of(context).size.width;
        return AlertDialog(
          title: Text(label),
          content: SingleChildScrollView(
            child: SizedBox(
              width: width * 0.8 > 300 ? 300 : width * 0.8,
              child: JsonQrDisplay(json,
                  interpret: ValueNotifier(true),
                  interpreter: JsonInterpreter(globalLabeler.value)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
          ],
        );
      },
    ),
    trailingWidget: MyCheckbox(storeKeys, 'Store keys', alwaysShowTitle: true),
    termsUrl: 'https://nerdster.org/terms.html',
    safetyUrl: 'https://nerdster.org/safety.html',
    forceIphone: forceIphone,
  );
}

class SignInWidget extends StatefulWidget {
  const SignInWidget({super.key});

  @override
  State<SignInWidget> createState() => _SignInWidgetState();
}

class _SignInWidgetState extends State<SignInWidget> {
  @override
  void initState() {
    super.initState();
    signInState.addListener(_update);
    globalLabeler.addListener(_update);
  }

  @override
  void dispose() {
    signInState.removeListener(_update);
    globalLabeler.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    bool hasIdentity = signInState.hasIdentity;
    bool hasDelegate = signInState.delegate != null;

    Widget iconWidget;
    String tooltip;

    if (hasIdentity && hasDelegate) {
      // Logic to determine delegate status
      KeyStatus delegateStatus = KeyStatus.active;
      String statusMsg = 'active';
      final labeler = globalLabeler.value;
      final resolver = labeler.delegateResolver;

      if (resolver != null) {
        final dKey = DelegateKey(signInState.delegate!);
        final iKey = signInState.identity;

        final IdentityKey? resolvedIdentity = resolver.getIdentityForDelegate(dKey);
        final String? revokeConstraint = resolver.getConstraintForDelegate(dKey);

        final resolvedMyIdentity = labeler.graph.resolveIdentity(iKey);
        final bool isAssociated =
            resolvedIdentity != null && resolvedIdentity == resolvedMyIdentity;
        final bool isRevoked = revokeConstraint != null;
        final bool povIsMyIdentity = signInState.pov == signInState.identity.value;

        if (!isAssociated) {
          delegateStatus = KeyStatus.revoked;
          // When viewing a different PoV the user may simply not be in that network—
          // qualify the message so it reads as informational rather than alarming.
          statusMsg = povIsMyIdentity
              ? 'not associated with identity'
              : 'not associated with identity (from this PoV)';
        } else if (isRevoked) {
          delegateStatus = KeyStatus.revoked;
          statusMsg = 'revoked';
        }
      }

      // Fully signed in: delegate key is blue filled.
      iconWidget = KeyIcon(type: KeyType.delegate, status: delegateStatus, presence: KeyPresence.owned);
      tooltip = 'Signed in with Identity and Delegate ($statusMsg)';
    } else if (hasIdentity) {
      // Identity only: green outlined (Nerdster never holds the private identity key).
      iconWidget = const KeyIcon(type: KeyType.identity, status: KeyStatus.active, presence: KeyPresence.known);
      tooltip = 'Signed in with Identity only';
    } else {
      iconWidget = const Icon(Icons.no_accounts, color: Colors.grey);
      tooltip = 'Not signed in';
    }

    return IconButton(
      tooltip: tooltip,
      icon: iconWidget,
      onPressed: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: SignInDialog(config: buildNerdsterSignInConfig()),
          ),
        );
      },
    );
  }
}
