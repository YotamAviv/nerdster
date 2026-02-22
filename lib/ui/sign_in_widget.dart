import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nerdster/key_store.dart';
import 'package:oneofus_common/ui/json_qr_display.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:nerdster/ui/util/my_checkbox.dart';
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
    bool hasIdentity = signInState.isSignedIn;
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
        final iKey = IdentityKey(signInState.identity);

        final IdentityKey? resolvedIdentity = resolver.getIdentityForDelegate(dKey);
        final String? revokeConstraint = resolver.getConstraintForDelegate(dKey);

        final resolvedMyIdentity = labeler.graph.resolveIdentity(iKey);

        // 1. Check Association: Is this delegate mapped to our current canonical identity?
        bool isAssociated = resolvedIdentity != null && resolvedIdentity == resolvedMyIdentity;

        // 2. Check Revocation: Is there a revocation constraint?
        bool isRevoked = revokeConstraint != null;

        if (!isAssociated) {
          delegateStatus = KeyStatus.revoked;
          statusMsg = "not associated with identity";
        } else if (isRevoked) {
          delegateStatus = KeyStatus.revoked;
          statusMsg = "revoked";
        }
      }

      // Delegate key is active/owned
      iconWidget = KeyIcon(
        type: KeyType.delegate,
        status: delegateStatus,
        isOwned: true,
      );
      tooltip = "Signed in with Identity and Delegate ($statusMsg)";
    } else if (hasIdentity) {
      iconWidget = const KeyIcon(
        type: KeyType.identity,
        status: KeyStatus.active,
        isOwned: false,
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

class SignInDialog extends StatefulWidget {
  /// When used as a standalone screen, provide [onDismiss] to signal the
  /// parent that the user is done. When used as a dialog, leave it null
  /// and the Dismiss button will call Navigator.pop.
  final VoidCallback? onDismiss;
  const SignInDialog({this.onDismiss, super.key});

  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  final ValueNotifier<bool> _storeKeys = ValueNotifier(true);

  // We pre-create the session so we can generate a valid Link widget immediately.
  late Future<SignInSession> _sessionFuture;

  // Track previous key tokens so we can fire animations on any key change
  // (including paste sign-in which may replace an already-present key).
  String? _prevIdentityToken;
  String? _prevDelegateToken;

  @override
  void initState() {
    super.initState();
    _prevIdentityToken = signInState.isSignedIn ? signInState.identity : null;
    _prevDelegateToken = signInState.delegate;
    signInState.addListener(_update);
    _sessionFuture = SignInSession.create();
  }

  @override
  void dispose() {
    signInState.removeListener(_update);
    _storeKeys.dispose();
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool hasIdentity = signInState.isSignedIn;
    final bool hasDelegate = signInState.delegate != null;
    final String? currentIdentity = hasIdentity ? signInState.identity : null;
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

    final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;

    Widget buildUniversalBtn(bool recommended) {
      return FutureBuilder<SignInSession>(
          future: _sessionFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _buildListButton(
                icon: Icons.link,
                label: 'App Link',
                subtitle:
                    'Universal Links (iOS) & App Links (Android)\nIdentity app must be available on same device.',
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
                  label: 'App Link',
                  subtitle:
                      'Universal Links (iOS) & App Links (Android)\nIdentity app must be available on same device.',
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
          label: 'URL scheme',
          subtitle: 'keymeid://...\nIdentity app must be available on same device',
          onPressed: () => _magicLinkSignIn(context),
          recommended: recommended,
        );

    Widget buildQrBtn(bool recommended) => _buildListButton(
          icon: Icons.qr_code,
          label: 'QR Code',
          subtitle: 'Scan sign-in parameters with your phone\'s identity app',
          onPressed: () => qrSignIn(context),
          recommended: recommended,
        );

    final bool isDev = Setting.get<bool>(SettingType.dev).value;

    List<Widget> buttons;
    if (isIOS) {
      buttons = [
        buildUniversalBtn(true),
        buildCustomBtn(false),
        buildQrBtn(false),
      ];
    } else if (isAndroid) {
      buttons = [
        buildCustomBtn(true),
        buildUniversalBtn(false),
        buildQrBtn(false),
      ];
    } else {
      // Desktop/Web
      buttons = [
        buildQrBtn(true),
        buildCustomBtn(false),
        buildUniversalBtn(false),
      ];
    }
    if (isDev) {
      buttons.add(_buildListButton(
        icon: Icons.content_paste,
        label: 'Paste Keys',
        subtitle: 'Paste JSON keys directly',
        onPressed: () => pasteSignIn(context),
        recommended: false,
      ));
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusTable(hasIdentity, hasDelegate,
                  identityArrived: identityArrived, delegateArrived: delegateArrived),
              const SizedBox(height: 12),

              // Sign-in method heading
              const Align(
                alignment: Alignment.centerLeft,
                child:
                    Text('Sign in using:', style: TextStyle(fontSize: 13, color: Colors.black54)),
              ),

              // Actions - Flat List
              ...buttons,
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dismiss: disabled when not signed in.
                  // In standalone mode (screen), calls onDismiss; in dialog mode, pops.
                  TextButton(
                    onPressed: hasIdentity
                        ? () {
                            if (widget.onDismiss != null) {
                              widget.onDismiss!();
                            } else {
                              Navigator.pop(context);
                            }
                          }
                        : null,
                    child: const Text('Dismiss'),
                  ),
                  Row(
                    children: [
                      if (hasDelegate)
                        TextButton.icon(
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () async {
                            await KeyStore.wipeKeys();
                            // Drop delegate only — keep identity so user can see it
                            signInState.signOut(clearIdentity: false);
                          },
                        ),
                      MyCheckbox(_storeKeys, 'Store keys'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onKeyAnimationComplete() {
    // Dialog stays open — user must explicitly dismiss.
  }

  Widget _buildStatusTable(bool hasIdentity, bool hasDelegate,
      {required bool identityArrived, required bool delegateArrived}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatusColumn(
          "Identity",
          hasIdentity,
          keyArrived: identityArrived,
          color: Colors.green,
          icon: hasIdentity ? Icons.vpn_key : Icons.vpn_key_outlined,
          json: hasIdentity ? signInState.identityJson : null,
        ),
        _buildStatusColumn(
          "Delegate",
          hasDelegate,
          keyArrived: delegateArrived,
          color: Colors.blue,
          icon: hasDelegate ? Icons.vpn_key : Icons.vpn_key_outlined,
          json: signInState.delegatePublicKeyJson,
        ),
      ],
    );
  }

  Widget _buildStatusColumn(String label, bool hasKey,
      {required bool keyArrived,
      required Color color,
      required IconData icon,
      required Json? json}) {
    return InkWell(
      onTap: hasKey ? () => _showKeyDetail(label, json) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThrowingKeyIcon(
              visible: hasKey,
              animate: keyArrived,
              icon: icon,
              color: color,
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
    required String label,
    required String subtitle,
    required VoidCallback onPressed,
    required bool recommended,
  }) {
    return ListTile(
      leading: Icon(icon),
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
            storeKeys: _storeKeys,
            useUniversalLink: useUniversalLink,
            autoLaunch: autoLaunch,
            onCancel: () {},
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
  final ValueNotifier<bool> storeKeys;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;
  final bool useUniversalLink;
  final bool autoLaunch;

  const MagicLinkDialog({
    super.key,
    required this.sessionFuture,
    required this.storeKeys,
    required this.onCancel,
    required this.onSuccess,
    this.useUniversalLink = false,
    this.autoLaunch = true,
  });

  @override
  State<MagicLinkDialog> createState() => _MagicLinkDialogState();
}

class _MagicLinkDialogState extends State<MagicLinkDialog> {
  SignInSession? _session;

  @override
  void initState() {
    super.initState();
    _initSession();
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
        storeKeys: widget.storeKeys,
        onDone: () {
          widget.onSuccess();
        },
      );
    } catch (e) {
      debugPrint("Error in magic link session: $e");
    }
  }

  @override
  void dispose() {
    _session?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
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
  final bool visible;
  final bool animate;
  final IconData icon;
  final Color color;
  final double iconSize;
  final VoidCallback? onAnimationComplete;

  const ThrowingKeyIcon({
    super.key,
    required this.visible,
    this.animate = false,
    required this.icon,
    required this.color,
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
    // Also fire if visible just became true (legacy path, for safety)
    final bool justBecameVisible = !oldWidget.visible && widget.visible;
    if (shouldAnimate || justBecameVisible) {
      debugPrint("ThrowingKeyIcon: Starting animation!");
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
      child: Icon(widget.icon, color: widget.color, size: widget.iconSize),
    );
  }
}
