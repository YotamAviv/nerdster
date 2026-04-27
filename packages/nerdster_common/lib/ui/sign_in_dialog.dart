import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nerdster_common/sign_in_session.dart';
import 'package:nerdster_common/ui/key_icon.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/ui/json_qr_display.dart';
import 'package:url_launcher/url_launcher.dart';

/// All project-specific sign-in dependencies, passed to [SignInDialog].
class SignInConfig {
  // Core auth
  final Future<SignInSession> Function() sessionFactory;
  final FirebaseFirestore firestore;
  final Future<void> Function(Json data, PkeKeyPair pke) onData;

  // Reactive state
  final ChangeNotifier stateNotifier;
  final bool Function() hasIdentity;
  final bool Function() hasDelegate;
  final Json? Function() identityJson;
  final Json? Function() delegatePublicKeyJson;
  final VoidCallback onSignOut;
  final VoidCallback onForgetIdentity;

  // Optional features (null = hidden)
  final Future<void> Function(BuildContext)? onPasteSignIn;
  final bool showPasteInitially; // show paste without 7-tap easter egg
  final String? devSignInLabel;   // "No identity app" section label; null = section hidden
  final Widget? devSignInLeading; // icon/image for dev sign-in button
  final Future<void> Function(BuildContext)? onDevSignIn;
  final Future<void> Function(BuildContext, String label, Json? json)? onKeyTap;
  final Widget? trailingWidget;   // shown at bottom-left (e.g. "Store keys" checkbox)
  final String? termsUrl;
  final String? safetyUrl;
  final bool forceIphone; // simulate iOS UI on non-iOS (for testing)

  const SignInConfig({
    required this.sessionFactory,
    required this.firestore,
    required this.onData,
    required this.stateNotifier,
    required this.hasIdentity,
    required this.hasDelegate,
    required this.identityJson,
    required this.delegatePublicKeyJson,
    required this.onSignOut,
    required this.onForgetIdentity,
    this.onPasteSignIn,
    this.showPasteInitially = false,
    this.devSignInLabel,
    this.devSignInLeading,
    this.onDevSignIn,
    this.onKeyTap,
    this.trailingWidget,
    this.termsUrl,
    this.safetyUrl,
    this.forceIphone = false,
  });
}

class SignInDialog extends StatefulWidget {
  final SignInConfig config;
  const SignInDialog({super.key, required this.config});

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
  late Future<SignInSession> _sessionFuture;
  String? _prevIdentityToken;
  String? _prevDelegateToken;

  SignInConfig get _c => widget.config;

  @override
  void initState() {
    super.initState();
    _prevHasIdentity = _c.hasIdentity();
    _xPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _xPulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _xPulseController, curve: Curves.easeInOut));
    _prevIdentityToken = _c.hasIdentity() ? _tokenOf(_c.identityJson()) : null;
    _prevDelegateToken = _tokenOf(_c.delegatePublicKeyJson());
    _c.stateNotifier.addListener(_update);
    _sessionFuture = _c.sessionFactory();
  }

  @override
  void dispose() {
    _c.stateNotifier.removeListener(_update);
    _xPulseController.dispose();
    _sessionFuture.then((s) => s.cancel()).catchError((_) {});
    super.dispose();
  }

  String? _tokenOf(Json? json) => json == null ? null : getToken(json);

  void _update() {
    if (!mounted) return;
    final bool nowHasIdentity = _c.hasIdentity();
    if (!_prevHasIdentity && nowHasIdentity) _xPulseController.forward(from: 0);
    _prevHasIdentity = nowHasIdentity;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool hasIdentity = _c.hasIdentity();
    final bool hasDelegate = _c.hasDelegate();

    final String? currentIdentityToken = hasIdentity ? _tokenOf(_c.identityJson()) : null;
    final String? currentDelegateToken = _tokenOf(_c.delegatePublicKeyJson());
    final bool identityArrived = currentIdentityToken != null && currentIdentityToken != _prevIdentityToken;
    final bool delegateArrived = currentDelegateToken != null && currentDelegateToken != _prevDelegateToken;

    if (identityArrived || delegateArrived) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {
          _prevIdentityToken = currentIdentityToken;
          _prevDelegateToken = currentDelegateToken;
        });
      });
    } else {
      _prevIdentityToken = currentIdentityToken;
      _prevDelegateToken = currentDelegateToken;
    }

    final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS || _c.forceIphone;
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final bool isMobile = _c.forceIphone || (!kIsWeb && (isIOS || isAndroid));

    Widget buildUniversalBtn() {
      return FutureBuilder<SignInSession>(
        future: _sessionFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildListButton(
              icon: Icons.link,
              label: 'https://one-of-us.net/...',
              subtitle: 'Use the ONE-OF-US.NET identity app',
              onPressed: () {},
            );
          }
          final session = snapshot.data!;
          final paramsJson = jsonEncode(session.forPhone);
          final base64Params = base64Url.encode(utf8.encode(paramsJson));
          final link = 'https://one-of-us.net/sign-in?parameters=$base64Params';
          return _buildListButton(
            icon: Icons.link,
            label: 'https://one-of-us.net/...',
            subtitle: 'Use the ONE-OF-US.NET identity app',
            onPressed: () {
              _magicLinkSignIn(context, useUniversalLink: true,
                  precreatedSessionFuture: _sessionFuture, autoLaunch: false);
              launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
            },
          );
        },
      );
    }

    Widget buildCustomBtn() => _buildListButton(
          icon: Icons.auto_fix_high,
          label: 'keymeid://...',
          subtitle: 'Use any keymeid associated identity app',
          onPressed: () => _magicLinkSignIn(context),
        );

    Widget buildQrBtn() => _buildListButton(
          icon: Icons.qr_code,
          label: 'QR Code',
          subtitle: 'Scan with an identity app to sign in',
          onPressed: () => _qrSignIn(context),
        );

    final bool showPaste = _c.showPasteInitially || _showPaste;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && hasIdentity) Navigator.of(context).pop();
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(12)),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Sign in',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      ScaleTransition(
                        scale: _xPulseScale,
                        child: Tooltip(
                          message: hasIdentity ? 'Close' : 'Sign in to close',
                          child: IconButton(
                            icon: Icon(Icons.close,
                                color: hasIdentity ? Colors.black87 : Colors.grey.shade300),
                            onPressed: hasIdentity ? () => Navigator.of(context).pop() : null,
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text.rich(TextSpan(
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                            children: [
                              TextSpan(text: 'Use your '),
                              TextSpan(text: 'Identity App',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              TextSpan(text: ' (ONE-OF-US.NET)'),
                            ],
                          )),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Icon(_expanded ? Icons.remove : Icons.add,
                              size: 18, color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _headingTapCount++;
                      if (_headingTapCount >= 7) _showPaste = true;
                    }),
                    child: Text('Identity app on this device',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey[700],
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                if (_expanded) buildCustomBtn(),
                buildUniversalBtn(),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text('Identity app on different device',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.blueGrey[700],
                          fontWeight: FontWeight.bold)),
                ),
                buildQrBtn(),

                // "No identity app" section — for mobile app store review requirements.
                // See comment in SignInConfig.devSignInLabel for details.
                if (isMobile && !hasIdentity && _c.devSignInLabel != null &&
                    _c.onDevSignIn != null) ...[
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
                    leadingWidget: _c.devSignInLeading,
                    label: _c.devSignInLabel!,
                    subtitle: 'Preview without your own identity',
                    onPressed: () => _c.onDevSignIn!(context),
                  ),
                ],

                if (_c.onPasteSignIn != null && showPaste) ...[
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
                    onPressed: () => _c.onPasteSignIn!(context),
                  ),
                ],

                const SizedBox(height: 8),
                if (!kIsWeb && (_c.termsUrl != null || _c.safetyUrl != null))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        children: [
                          const TextSpan(text: 'By signing in, you agree to our '),
                          if (_c.termsUrl != null)
                            TextSpan(
                              text: 'Terms of Service',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(Uri.parse(_c.termsUrl!),
                                    mode: LaunchMode.externalApplication),
                            ),
                          if (_c.termsUrl != null && _c.safetyUrl != null)
                            const TextSpan(text: ' and '),
                          if (_c.safetyUrl != null)
                            TextSpan(
                              text: 'Safety Policy',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(Uri.parse(_c.safetyUrl!),
                                    mode: LaunchMode.externalApplication),
                            ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_c.trailingWidget != null) _c.trailingWidget!,
                    if (hasDelegate)
                      TextButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: _c.onSignOut,
                      )
                    else if (hasIdentity)
                      TextButton.icon(
                        icon: const Icon(Icons.person_remove_outlined),
                        label: const Text('Forget identity'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: _c.onForgetIdentity,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTable(bool hasIdentity, bool hasDelegate,
      {required bool identityArrived, required bool delegateArrived}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatusColumn('Identity', KeyType.identity,
            hasIdentity ? KeyPresence.known : KeyPresence.absent,
            keyArrived: identityArrived, json: hasIdentity ? _c.identityJson() : null),
        _buildStatusColumn('Delegate', KeyType.delegate,
            hasDelegate ? KeyPresence.owned : KeyPresence.absent,
            keyArrived: delegateArrived, json: _c.delegatePublicKeyJson()),
      ],
    );
  }

  Widget _buildStatusColumn(String label, KeyType keyType, KeyPresence presence,
      {required bool keyArrived, required Json? json}) {
    final bool hasKey = presence != KeyPresence.absent;
    final Color color = keyType == KeyType.identity ? Colors.green : Colors.blue;
    final bool tappable = hasKey && _c.onKeyTap != null;
    return InkWell(
      onTap: tappable ? () => _c.onKeyTap!(context, label, json) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThrowingKeyIcon(presence: presence, animate: keyArrived, keyType: keyType, iconSize: 28),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(hasKey ? 'present' : 'not present',
                    style: TextStyle(fontSize: 11, color: hasKey ? color : Colors.grey)),
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
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: leadingWidget ?? Icon(icon),
      title: Text(label),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      onTap: onPressed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Future<void> _qrSignIn(BuildContext context) async {
    final completer = Completer<void>();
    final session = await _c.sessionFactory();
    // ignore: unawaited_futures
    session.listen(
      firestore: _c.firestore,
      onData: _c.onData,
      onDone: () {
        if (!completer.isCompleted) {
          if (context.mounted) Navigator.of(context).pop();
          completer.complete();
        }
      },
    );
    await showDialog(
      context: context,
      builder: (_) => QrSignInDialog(forPhone: session.forPhone),
    ).then((_) {
      if (!completer.isCompleted) {
        session.cancel();
        completer.complete();
      }
    });
    await completer.future;
  }

  Future<void> _magicLinkSignIn(BuildContext context,
      {bool useUniversalLink = false,
      Future<SignInSession>? precreatedSessionFuture,
      bool autoLaunch = true}) async {
    final completer = Completer<void>();
    final sessionFuture = precreatedSessionFuture ?? _c.sessionFactory();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => MagicLinkDialog(
        sessionFuture: sessionFuture,
        firestore: _c.firestore,
        onData: _c.onData,
        useUniversalLink: useUniversalLink,
        autoLaunch: autoLaunch,
        onCancel: () {},
        onTimeout: () {
          if (mounted) setState(() => _timeoutFired = true);
        },
        onSuccess: () {
          Navigator.of(dialogContext).pop();
          completer.complete();
        },
      ),
    );
  }
}

class QrSignInDialog extends StatelessWidget {
  final Json forPhone;
  const QrSignInDialog({required this.forPhone, super.key});

  @override
  Widget build(BuildContext context) {
    final Size availableSize = MediaQuery.of(context).size;
    final double width = min(availableSize.width * 0.5, availableSize.height * 0.8);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Scan with the ONE-OF-US.NET app',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                JsonQrDisplay(forPhone, interpret: ValueNotifier(false)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MagicLinkDialog extends StatefulWidget {
  final Future<SignInSession> sessionFuture;
  final FirebaseFirestore firestore;
  final Future<void> Function(Json data, PkeKeyPair pke) onData;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;
  final VoidCallback? onTimeout;
  final bool useUniversalLink;
  final bool autoLaunch;

  const MagicLinkDialog({
    super.key,
    required this.sessionFuture,
    required this.firestore,
    required this.onData,
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
      setState(() => _showExplanation = true);
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

      if (widget.autoLaunch) {
        await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      }

      session.listen(
        firestore: widget.firestore,
        onData: widget.onData,
        onDone: widget.onSuccess,
      );
    } catch (e) {
      debugPrint('MagicLinkDialog error: $e');
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                'Waiting for identity app response... If nothing is happening:',
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Make sure you have the ONE-OF-US.NET identity app installed on this device',
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (defaultTargetPlatform == TargetPlatform.iOS ||
                      defaultTargetPlatform != TargetPlatform.android)
                    InkWell(
                      onTap: () => launchUrl(
                          Uri.parse('https://apps.apple.com/us/app/one-of-us/id6739090070'),
                          mode: LaunchMode.externalApplication),
                      child: Image.network('https://one-of-us.net/common/img/apple.webp', height: 40),
                    ),
                  if (defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform != TargetPlatform.iOS)
                    InkWell(
                      onTap: () => launchUrl(
                          Uri.parse(
                              'https://play.google.com/store/apps/details?id=net.oneofus.app'),
                          mode: LaunchMode.externalApplication),
                      child:
                          Image.network('https://one-of-us.net/common/img/google.webp', height: 40),
                    ),
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
                      launchUrl(
                          Uri.parse(
                              'https://one-of-us.net/sign-in?parameters=$base64Params'),
                          mode: LaunchMode.externalApplication);
                    },
                    child: const Text('https://one-of-us.net/...',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                            decoration: TextDecoration.underline)),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
