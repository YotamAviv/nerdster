import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/gestures.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:nerdster/key_storage_coordinator.dart';
import 'package:oneofus_common/ui/json_qr_display.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:nerdster/ui/util/my_checkbox.dart';
import 'package:nerdster/ui/util_ui.dart';
import 'package:nerdster/paste_sign_in.dart';
import 'package:nerdster/qr_sign_in.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/sign_in_session.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/logic/interpreter.dart';
import 'package:nerdster/ui/key_icon.dart';
import 'package:oneofus_common/keys.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/link.dart';

/// Key icon convention (see key_icon.dart for full details):
///   - Green outlined  = identity key (Nerdster never holds the private identity key)
///   - Blue filled     = delegate key, owned (private key present on device)
///   - Blue outlined   = delegate key, not owned / missing
///
/// Set to true (via ?forceIphone=true URL param) to simulate iOS sign-in UI on non-iOS platforms.
final bool forceIphone = kIsWeb && Uri.base.queryParameters['forceIphone'] == 'true';

/// Hardcoded developer identity public key for "Use developer's Point of View" sign-in.
const Map<String, dynamic> _kDevIdentityKey = {
  'crv': 'Ed25519',
  'kty': 'OKP',
  'x': 'Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo',
};

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
      String statusMsg = "active";

      final labeler = globalLabeler.value;
      final resolver = labeler.delegateResolver;

      if (resolver != null) {
        final dKey = DelegateKey(signInState.delegate!);
        final iKey = signInState.identity;

        final IdentityKey? resolvedIdentity = resolver.getIdentityForDelegate(dKey);
        final String? revokeConstraint = resolver.getConstraintForDelegate(dKey);

        final resolvedMyIdentity = labeler.graph.resolveIdentity(iKey);
        final bool isAssociated = resolvedIdentity != null && resolvedIdentity == resolvedMyIdentity;
        final bool isRevoked = revokeConstraint != null;
        final bool povIsMyIdentity = signInState.pov == signInState.identity.value;

        if (!isAssociated) {
          delegateStatus = KeyStatus.revoked;
          // When viewing a different PoV the user may simply not be in that network—
          // qualify the message so it reads as informational rather than alarming.
          statusMsg = povIsMyIdentity
              ? "not associated with identity"
              : "not associated with identity (from this PoV)";
        } else if (isRevoked) {
          delegateStatus = KeyStatus.revoked;
          statusMsg = "revoked";
        }
      }

      // Fully signed in: delegate key is blue filled.
      iconWidget = KeyIcon(
        type: KeyType.delegate,
        status: delegateStatus,
        presence: KeyPresence.owned,
      );
      tooltip = "Signed in with Identity and Delegate ($statusMsg)";
    } else if (hasIdentity) {
      // Identity only: green outlined (Nerdster never holds the private identity key).
      iconWidget = const KeyIcon(
        type: KeyType.identity,
        status: KeyStatus.active,
        presence: KeyPresence.known,
      );
      tooltip = "Signed in with Identity only";
    } else {
      iconWidget = const Icon(Icons.no_accounts, color: Colors.grey);
      tooltip = "Not signed in";
    }

    return IconButton(
      tooltip: tooltip,
      icon: iconWidget,
      onPressed: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Dialog(
            backgroundColor: Colors.transparent,
            child: SignInDialog(),
          ),
        );
      },
    );
  }
}

/*
Current state:

There are devices out there with old versions of the identity app, and so
these must be maintained working.
I do plan to transition to something clearer, and so for a while
we'll have two ways of doing things.

The fallback web pages hosted at https://one-of-us.net/ need to be maintained
as well.

- Vouch (used in invitation links to share an identity for vouching):
  - keymeid://vouch#<base64Url_json_payload>
  - https://one-of-us.net/vouch#<base64Url_json_payload>
  Note: The payload is passed in the URI fragment (`#`), not as a query parameter. 
  The identity app parses this on cold-starts and deep-link streams.

- Sign-in:
  - Nerdster generates: keymeid://signin?parameters=<base64Url_session_payload>
  - Nerdster generates: https://one-of-us.net/sign-in?parameters=<base64Url_session_payload>
  Note: The identity app currently routes any `keymeid://` request where host != 'vouch' 
  as a sign-in attempt, grabbing `?parameters=`. For HTTP, it looks for paths containing 
  `sign-in` and grabs `?data=` or `?parameters=`.


Future state:

Don't invite trouble: hyphens, underscores, capital letters...
(Cloud functions cause issues with camel case.)

Verbs: signin, vouch, block, clear

- Vouch:
  - keymeid://vouch#<base64Url_json_payload>
  - https://one-of-us.net/vouch#<base64Url_json_payload>

- Sign-in:
  - keymeid://signin#<base64Url_session_payload>
  - https://one-of-us.net/signin#<base64Url_session_payload>

- Block:
  - keymeid://block#<base64Url_json_payload>
  - https://one-of-us.net/block#<base64Url_json_payload>

- Clear:
  - keymeid://clear#<base64Url_json_payload>
  - https://one-of-us.net/clear#<base64Url_json_payload>
*/


/*
Lingo:
  - https://one-of-us.net/ (universal link)
  - keymeid:// (custom URL scheme)

Background:
- I had universal link misconfigured on Android for a while.
- I prefer custom URL schemes as they're open and heterogeneous.
- I can show a fallback at https://one-of-us.net/sign-in, but I can't control what happens
  when keymeid:// fails (other than timeout).
- I don't want to confuse the user with too many options.
- Apple demanded that there be a way to enter without another app. I don't want this to be *my* app, 
  but I've succumbed; Enter the Nerdster! enters as me.
- I used to try and "recommend" an option; ditching that for now (UI code in place, non recommened.)

Settlement:
- keep it simple: https://one-of-us.net/ (universal link).
- add a +/- to show other options
- show keymeid:// (custom URL scheme) on https://one-of-us.net/sign-in fallback page.

So:
Regardless of platform, show:
Identity app on this device:
  - https://one-of-us.net/ (universal link)
Identity app on different device:
  - Scan QR code
No identity app: (* see "Restrictions for No identity app:" below) 
  - Enter the Nerdster!

A "+" / "-" toggle on the blue header box that says, "Use your identity app (ONE-OF-US.NET)"
can be used to show more methods, specifically this:
Identity app on this device:
  - keymeid:// (custom scheme) [note that this is placed in 1'st place now.]
  - https://one-of-us.net/ (universal link)
Identity app on different device:
  - Scan QR code
No identity app: (* see "Restrictions for No identity app:" below) 
  - Enter the Nerdster!

A 10 second timeout when attempting keymeid:// (custom scheme) sign in
should show an explanation dialog and alternate link
and the https://one-of-us.net/ option if it was previously hidden [note that it wasn't hidden.].
(https://one-of-us.net/sign-in should never fail as there's a web page there)

Restrictions for showing No identity app:
- only on mobile apps (not web app on mobile devices)
- only if there is currently no signed in identity (delegate not required).

Clicking the text, "Identity app on this device" 7 times will show all options including
Developers:
- Paste keys
*/
class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key});

  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> with SingleTickerProviderStateMixin {
  int _headingTapCount = 0;
  bool _showPaste = false;
  bool _expanded = false;
  bool _prevHasIdentity = false;
  bool _timeoutFired = false;
  late AnimationController _xPulseController;
  late Animation<double> _xPulseScale;

  // We pre-create the session so we can generate a valid Link widget immediately.
  late Future<SignInSession> _sessionFuture;

  // Track previous key tokens so we can fire animations on any key change
  // (including paste sign-in which may replace an already-present key).
  IdentityKey? _prevIdentityToken;
  String? _prevDelegateToken;

  @override
  void initState() {
    super.initState();
    _prevHasIdentity = signInState.hasIdentity;
    _xPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _xPulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _xPulseController, curve: Curves.easeInOut));
    _prevIdentityToken = signInState.hasIdentity ? signInState.identity : null;
    _prevDelegateToken = signInState.delegate;
    signInState.addListener(_update);
    _sessionFuture = SignInSession.create();
  }

  @override
  void dispose() {
    signInState.removeListener(_update);
    _xPulseController.dispose();
    _sessionFuture.then((s) => s.cancel()).catchError((_) {});
    super.dispose();
  }

  void _update() {
    if (!mounted) return;
    final bool nowHasIdentity = signInState.hasIdentity;
    if (!_prevHasIdentity && nowHasIdentity) {
      _xPulseController.forward(from: 0);
    }
    _prevHasIdentity = nowHasIdentity;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool hasIdentity = signInState.hasIdentity;
    final bool hasDelegate = signInState.delegate != null;
    final IdentityKey? currentIdentity = hasIdentity ? signInState.identity : null;
    final String? currentDelegate = signInState.delegate;

    // Animate when the key token is new or changed (covers paste re-sign-in).
    final bool identityArrived = currentIdentity != null && currentIdentity != _prevIdentityToken;
    final bool delegateArrived = currentDelegate != null && currentDelegate != _prevDelegateToken;
    if (identityArrived || delegateArrived) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _prevIdentityToken = currentIdentity;
            _prevDelegateToken = currentDelegate;
          });
        }
      });
    } else {
      _prevIdentityToken = currentIdentity;
      _prevDelegateToken = currentDelegate;
    }

    final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS || forceIphone;
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final bool isMobile = forceIphone || (!kIsWeb && (isIOS || isAndroid));

    Widget buildUniversalBtn(bool recommended) {
      return FutureBuilder<SignInSession>(
          future: _sessionFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _buildListButton(
                icon: Icons.link,
                label: 'https://one-of-us.net/...',
                subtitle: 'Use the ONE-OF-US.NET identity app',
                onPressed: () {},
                recommended: recommended,
              );
            }
            final session = snapshot.data!;
            final paramsJson = jsonEncode(session.forPhone);
            final base64Params = base64Url.encode(utf8.encode(paramsJson));
            final link = 'https://one-of-us.net/sign-in?parameters=$base64Params';

            return Link(
              uri: Uri.parse(link),
              target: LinkTarget.blank,
              builder: (context, followLink) {
                return _buildListButton(
                  icon: Icons.link,
                  label: 'https://one-of-us.net/...',
                  subtitle: 'Use the ONE-OF-US.NET identity app',
                  onPressed: () {
                    _magicLinkSignIn(context,
                        useUniversalLink: true,
                        precreatedSessionFuture: _sessionFuture,
                        autoLaunch: false);
                    followLink?.call();
                  },
                  recommended: recommended,
                );
              },
            );
          });
    }

    Widget buildCustomBtn(bool recommended) => _buildListButton(
          icon: Icons.auto_fix_high,
          label: 'keymeid://...',
          subtitle: 'Use any keymeid associated identity app',
          onPressed: () => _magicLinkSignIn(context),
          recommended: recommended,
        );

    Widget buildQrBtn(bool recommended) => _buildListButton(
          icon: Icons.qr_code,
          label: 'QR Code',
          subtitle: 'Scan with an identity app to sign in',
          onPressed: () => qrSignIn(context),
          recommended: recommended,
        );

    final bool isDev = Setting.get<bool>(SettingType.dev).value;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop && hasIdentity) Navigator.of(context).pop();
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: kBorderRadius,
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            clipBehavior: Clip.hardEdge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title row with dynamic title + X close button
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sign in',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ScaleTransition(
                        scale: _xPulseScale,
                        child: Tooltip(
                          message: hasIdentity ? 'Close' : 'Sign in to close',
                          child: IconButton(
                            icon: Icon(
                              Icons.close,
                              color: hasIdentity
                                  ? Colors.black87
                                  : Colors.grey.shade300,
                            ),
                            onPressed: hasIdentity
                                ? () => Navigator.of(context).pop()
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusTable(hasIdentity, hasDelegate,
                    identityArrived: identityArrived, delegateArrived: delegateArrived),
                if (!hasDelegate) ...[
                  const SizedBox(height: 8),
                  // Blue header box — tap the +/- icon to expand/collapse.
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                              children: [
                                const TextSpan(text: 'Use your '),
                                const TextSpan(
                                  text: 'Identity App',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const TextSpan(text: ' (ONE-OF-US.NET)'),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Icon(
                            _expanded ? Icons.remove : Icons.add,
                            size: 18,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Section 1: This Device
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _headingTapCount++;
                        if (_headingTapCount >= 7) {
                          _showPaste = true;
                        }
                      });
                    },
                    child: Text('Identity app on this device',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey[700],
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                if (_expanded) buildCustomBtn(false),
                buildUniversalBtn(false),

                const SizedBox(height: 8),

                // Section 2: Different Device
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text('Identity app on different device',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.blueGrey[700],
                          fontWeight: FontWeight.bold)),
                ),
                buildQrBtn(false),

                // Section 3: No identity app (native mobile apps only)
                if (isMobile && !hasIdentity) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text('No identity app',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey[700],
                            fontWeight: FontWeight.bold)),
                  ),
                  _buildListButton(
                    icon: Icons.visibility,
                    leadingWidget: Image.asset('assets/images/nerd.png', width: 24, height: 24),
                    label: 'Enter the Nerdster',
                    subtitle: 'Preview without your own identity',
                    onPressed: _signInAsDev,
                    recommended: false,
                  ),
                ],

                // Developers section (7-tap easter egg)
                if (isDev || _showPaste) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text('Developers',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey[700],
                            fontWeight: FontWeight.bold)),
                  ),
                  _buildListButton(
                    icon: Icons.content_paste,
                    label: 'Paste Keys',
                    subtitle: 'Paste JSON keys directly',
                    onPressed: () => pasteSignIn(context),
                    recommended: false,
                  ),
                ],
                const SizedBox(height: 8),
                if (!kIsWeb)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        children: [
                          const TextSpan(text: 'By signing in, you agree to our '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => myLaunchUrl('https://nerdster.org/terms.html'),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Safety Policy',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => myLaunchUrl('https://nerdster.org/safety.html'),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasDelegate)
                      TextButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () {
                          signInState.signOut(clearIdentity: false);
                        },
                      )
                    else if (hasIdentity)
                      TextButton.icon(
                        icon: const Icon(Icons.person_remove_outlined),
                        label: const Text('Forget identity'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () {
                          signInState.signOut(clearIdentity: true);
                        },
                      ),
                    MyCheckbox(storeKeys, 'Store keys', alwaysShowTitle: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onKeyAnimationComplete() {
    // Dialog stays open — user must explicitly dismiss.
  }

  Future<void> _signInAsDev() async {
    final key = await crypto.parsePublicKey(_kDevIdentityKey);
    final Json keyJson = await key.json;
    FedKey(keyJson, kNativeEndpoint); // registers in Jsonish (required before pov setter)
    signInState.pov = getToken(keyJson);
    if (mounted) Navigator.pop(context);
  }

  Widget _buildStatusTable(bool hasIdentity, bool hasDelegate,
      {required bool identityArrived, required bool delegateArrived}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatusColumn(
          'Identity',
          KeyType.identity,
          hasIdentity ? KeyPresence.known : KeyPresence.absent,
          keyArrived: identityArrived,
          json: hasIdentity ? signInState.identityJson : null,
        ),
        _buildStatusColumn(
          'Delegate',
          KeyType.delegate,
          hasDelegate ? KeyPresence.owned : KeyPresence.absent,
          keyArrived: delegateArrived,
          json: signInState.delegatePublicKeyJson,
        ),
      ],
    );
  }

  Widget _buildStatusColumn(String label, KeyType keyType, KeyPresence presence,
      {required bool keyArrived,
      required Json? json}) {
    final bool hasKey = presence != KeyPresence.absent;
    final Color color = keyType == KeyType.identity ? Colors.green : Colors.blue;
    return InkWell(
      onTap: hasKey ? () => _showKeyDetail(label, json) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThrowingKeyIcon(
              presence: presence,
              animate: keyArrived,
              keyType: keyType,
              iconSize: 28,
              onAnimationComplete: _onKeyAnimationComplete,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(
                  hasKey ? 'present' : 'not present',
                  style: TextStyle(fontSize: 11, color: hasKey ? color : Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListButton({
    required IconData icon,
    Widget? leadingWidget,
    required String label,
    required String subtitle,
    required VoidCallback onPressed,
    required bool recommended,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: leadingWidget ?? Icon(icon),
      title: Row(
        children: [
          Text(label),
          if (recommended) ...[const SizedBox(width: 6), _recommendedChip()],
        ],
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      onTap: onPressed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _recommendedChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('Recommended', style: TextStyle(color: Colors.white, fontSize: 10)),
      );

  void _showKeyDetail(String title, Json? json) {
    showDialog(
        context: context,
        builder: (context) {
          double width = MediaQuery.of(context).size.width;
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
                child: SizedBox(
              width: min(width * 0.8, 300.0),
              child: JsonQrDisplay(json,
                  interpret: ValueNotifier(true),
                  interpreter: NerdsterInterpreter(globalLabeler.value)),
            )),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
            ],
          );
        });
  }

  Future<void> _magicLinkSignIn(BuildContext context,
      {bool useUniversalLink = false,
      Future<SignInSession>? precreatedSessionFuture,
      bool autoLaunch = true}) async {
    final completer = Completer<void>();

    // Start session creation immediately
    final sessionFuture = precreatedSessionFuture ?? SignInSession.create();

    await showDialog(
        context: context,
        barrierDismissible: false, // Force them to use cancel button
        builder: (dialogContext) {
          return MagicLinkDialog(
            sessionFuture: sessionFuture,
            useUniversalLink: useUniversalLink,
            autoLaunch: autoLaunch,
            onCancel: () {},
            onTimeout: () {
              if (mounted) {
                setState(() {
                  _timeoutFired = true;
                });
              }
            },
            onSuccess: () {
              Navigator.of(dialogContext).pop();
              completer.complete();
            },
          );
        });
  }
}

class MagicLinkDialog extends StatefulWidget {
  final Future<SignInSession> sessionFuture;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;
  final VoidCallback? onTimeout;
  final bool useUniversalLink;
  final bool autoLaunch;

  const MagicLinkDialog({
    super.key,
    required this.sessionFuture,
    required this.onCancel,
    required this.onSuccess,
    this.onTimeout,
    this.useUniversalLink = false,
    this.autoLaunch = true,
  });

  @override
  State<MagicLinkDialog> createState() => _MagicLinkDialogState();
}

class _MagicLinkDialogState extends State<MagicLinkDialog> {
  SignInSession? _session;
  Timer? _timer;
  bool _showExplanation = false;

  @override
  void initState() {
    super.initState();
    _initSession();
    _timer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() {
        _showExplanation = true;
      });
      widget.onTimeout?.call();
    });
  }

  Future<void> _initSession() async {
    try {
      final session = await widget.sessionFuture;
      if (!mounted) return;
      _session = session;

      final paramsJson = jsonEncode(session.forPhone);
      final base64Params = base64Url.encode(utf8.encode(paramsJson));
      final link = widget.useUniversalLink
          ? 'https://one-of-us.net/sign-in?parameters=$base64Params'
          : 'keymeid://signin?parameters=$base64Params';

      // Launch immediately
      if (widget.autoLaunch) {
        await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      }

      // Listen
      session.listen(
        onDone: () {
          widget.onSuccess();
        },
        method: widget.useUniversalLink ? SignInMethod.oneOfUsNet : SignInMethod.keymeid,
      );
    } catch (e) {
      debugPrint("Error in magic link session: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _session?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_showExplanation) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
            ] else ...[
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Waiting for identity app response... If nothing is happening:",
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Make sure you have the ONE-OF-US.NET identity app installed on this device",
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (defaultTargetPlatform == TargetPlatform.iOS)
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('https://apps.apple.com/us/app/one-of-us/id6739090070'), mode: LaunchMode.externalApplication),
                      child: Image.network('https://one-of-us.net/common/img/apple.webp', height: 40),
                    ),
                  if (defaultTargetPlatform == TargetPlatform.android)
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=net.oneofus.app'), mode: LaunchMode.externalApplication),
                      child: Image.network('https://one-of-us.net/common/img/google.webp', height: 40),
                    ),
                  if (defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.android) ...[
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('https://apps.apple.com/us/app/one-of-us/id6739090070'), mode: LaunchMode.externalApplication),
                      child: Image.network('https://one-of-us.net/common/img/apple.webp', height: 40),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=net.oneofus.app'), mode: LaunchMode.externalApplication),
                      child: Image.network('https://one-of-us.net/common/img/google.webp', height: 40),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "If you do have the app installed, app associations can be finicky; try this alternate link:",
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 14),
              ),
              if (_session != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: InkWell(
                    onTap: () {
                      final paramsJson = jsonEncode(_session!.forPhone);
                      final base64Params = base64Url.encode(utf8.encode(paramsJson));
                      final link = 'https://one-of-us.net/sign-in?parameters=$base64Params';
                      launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                    },
                    child: const Text(
                      'https://one-of-us.net/...',
                      style: TextStyle(fontSize: 14, color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            )
          ],
        ),
      ),
    );
  }
}

class ThrowingKeyIcon extends StatefulWidget {
  final KeyPresence presence;
  final bool animate;
  final KeyType keyType;
  final double iconSize;
  final VoidCallback? onAnimationComplete;

  const ThrowingKeyIcon({
    super.key,
    required this.presence,
    this.animate = false,
    required this.keyType,
    this.iconSize = 48,
    this.onAnimationComplete,
  });

  @override
  State<ThrowingKeyIcon> createState() => _ThrowingKeyIconState();
}

class _ThrowingKeyIconState extends State<ThrowingKeyIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _offset;
  late final Animation<double> _rot;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

    // Jerky "throw" animation sequence
    _offset = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(-8, 0)), weight: 12),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(-8, 0), end: const Offset(26, -8)), weight: 22),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(26, -8), end: const Offset(46, -14)), weight: 22),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(46, -14), end: const Offset(0, 0)), weight: 44),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _rot = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -3 * pi / 180), weight: 12),
      TweenSequenceItem(tween: Tween(begin: -3 * pi / 180, end: 5 * pi / 180), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 5 * pi / 180, end: 8 * pi / 180), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 8 * pi / 180, end: 0.0), weight: 44),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(ThrowingKeyIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fire animation when animate flips to true (key just arrived)
    final bool shouldAnimate = widget.animate && !oldWidget.animate;
    // Also fire when key transitions from absent to present
    final bool justArrived = oldWidget.presence == KeyPresence.absent &&
        widget.presence != KeyPresence.absent;
    if (shouldAnimate || justArrived) {
      debugPrint('ThrowingKeyIcon: Starting animation!');
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.translate(
        offset: _offset.value,
        child: Transform.rotate(
          angle: _rot.value,
          child: child,
        ),
      ),
      child: KeyIcon(type: widget.keyType, presence: widget.presence, size: widget.iconSize),
    );
  }
}
