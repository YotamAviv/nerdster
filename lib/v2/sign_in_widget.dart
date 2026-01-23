import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/paste_sign_in.dart';
import 'package:nerdster/qr_sign_in.dart';
import 'package:nerdster/sign_in_session.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/interpreter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  }

  @override
  void dispose() {
    signInState.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    bool hasIdentity = signInState.isSignedIn;
    bool hasDelegate = signInState.delegate != null;

    IconData icon;
    Color? color;
    String tooltip;

    if (hasIdentity && hasDelegate) {
      icon = Icons.vpn_key;
      color = Colors.blue;
      tooltip = "Signed in with Identity and Delegate";
    } else if (hasIdentity) {
      icon = Icons.vpn_key;
      color = Colors.green;
      tooltip = "Signed in with Identity only";
    } else {
      icon = Icons.no_accounts; // or login
      color = Colors.grey;
      tooltip = "Not signed in";
    }

    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const SignInDialog(),
          );
        },
      ),
    );
  }
}

class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key});

  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  final ValueNotifier<bool> _storeKeys = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    signInState.addListener(_update);
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

    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              clipBehavior: Clip.none,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Sign In Status", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  _buildStatusTable(hasIdentity, hasDelegate),
                  const SizedBox(height: 32),
                  
                  // Actions - Horizontal Layout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _buildSquareButton(
                          context,
                          icon: Icons.qr_code,
                          label: 'QR Sign-in',
                          onPressed: () => qrSignIn(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSquareButton(
                          context,
                          icon: Icons.link,
                          label: 'Magic Link',
                          onPressed: () => _magicLinkSignIn(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSquareButton(
                          context,
                          icon: Icons.content_paste,
                          label: 'Paste',
                          onPressed: () => pasteSignIn(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [MyCheckbox(_storeKeys, 'Store keys')],
                  ),

                  if (hasIdentity) ...[
                    const Divider(height: 32),
                     TextButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          await KeyStore.wipeKeys();
                          signInState.signOut();
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                  ]
                ],
              ),
            ),
          ),
        ));
  }

  void _onKeyAnimationComplete() {
    if (mounted && signInState.isSignedIn) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  Widget _buildStatusTable(bool hasIdentity, bool hasDelegate) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusColumn(
            "Identity",
            hasIdentity,
            Colors.green,
            hasIdentity ? Icons.vpn_key : Icons.vpn_key_outlined,
            hasIdentity ? signInState.identityJson : null,
          ),
        ),
        Expanded(
          child: _buildStatusColumn(
            "Delegate",
            hasDelegate,
            Colors.blue,
            hasDelegate ? Icons.vpn_key : Icons.vpn_key_outlined,
            signInState.delegatePublicKeyJson,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusColumn(
      String label, bool hasKey, Color color, IconData icon, Json? json) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(
              hasKey ? Icons.check : Icons.not_interested,
              color: hasKey ? Colors.green : Colors.grey,
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 8),
        IconButton(
          icon: ThrowingKeyIcon(
            visible: hasKey,
            icon: icon,
            color: color,
            onAnimationComplete: _onKeyAnimationComplete,
          ),
          onPressed: hasKey ? () => _showKeyDetail(label, json) : null,
          tooltip: hasKey ? "View $label Key" : "$label Key Missing",
        ),
      ],
    );
  }

  Widget _buildSquareButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onPressed}) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showKeyDetail(String title, Json? json) {
    showDialog(context: context, builder: (context) {
      double width = MediaQuery.of(context).size.width;
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SizedBox(
            width: min(width * 0.8, 300.0),
            child: JsonQrDisplay(json, interpret: ValueNotifier(true), interpreter: V2Interpreter(globalLabeler.value)),
          )
        ),
        actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Close"))],
      );
    });
  }

  Future<void> _magicLinkSignIn(BuildContext context) async {
    final completer = Completer<void>();
    
    // Start session creation immediately
    final sessionFuture = SignInSession.create();

    await showDialog(
      context: context,
      barrierDismissible: false, // Force them to use cancel button
      builder: (dialogContext) {
        return MagicLinkDialog(
          sessionFuture: sessionFuture,
          storeKeys: _storeKeys,
          onCancel: () {
            // Logic handled in widget
          },
          onSuccess: () {
             Navigator.of(dialogContext).pop();
             completer.complete();
             // We do NOT pop the main context here, because we want the main dialog
             // to show the "throw" animation when it detects the keys are present.
             // The main dialog will then close itself after the animation.
          },
        );
      }
    );
  }
}

class MagicLinkDialog extends StatefulWidget {
  final Future<SignInSession> sessionFuture;
  final ValueNotifier<bool> storeKeys;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;

  const MagicLinkDialog({
    super.key,
    required this.sessionFuture,
    required this.storeKeys,
    required this.onCancel,
    required this.onSuccess,
  });

  @override
  State<MagicLinkDialog> createState() => _MagicLinkDialogState();
}

class _MagicLinkDialogState extends State<MagicLinkDialog> {
  SignInSession? _session;
  String? _link;
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    try {
      final session = await widget.sessionFuture;
      if (!mounted) return;
      
      setState(() {
        _session = session;
        final paramsJson = jsonEncode(session.forPhone);
        final base64Params = base64Url.encode(utf8.encode(paramsJson));
        // We do *not* Uri.encodeComponent because base64Url is url safe already 
        // (but some libs might prefer it being encoded anyway if it has == padding. 
        // base64Url usually avoids that or uses safe chars). 
        // Actually flutter's Uri.queryParameters decoding handles standard encodings.
        // Let's stick clearly to the receiving logic: 
        // 1. Get query param "parameters" 
        // 2. base64Url.decode
        _link = 'keymeid://signin?parameters=$base64Params';
      });

      // Launch immediately
      if (_link != null) {
        // ignore: unused_local_variable
        final launched = await launchUrl(Uri.parse(_link!));
        if (mounted) {
             setState(() {
               _launched = true;
             });
        }
      }

      // Listen
      session.listen(
        storeKeys: widget.storeKeys.value,
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
             Text(_launched ? "Magic Link Launched..." : "Preparing Magic Link...",
                style: const TextStyle(fontWeight: FontWeight.bold)
             ),
             const SizedBox(height: 16),
             if (_link != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey.shade100,
                  child: Text(_link!, 
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () { 
                     // Retry launch
                     launchUrl(Uri.parse(_link!));
                  }, 
                  child: const Text("Launch again")
                ),
             ],
             const SizedBox(height: 8),
             // Store keys checkbox removed from here as it is now in the main dialog
             const SizedBox(height: 8),
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
  final IconData icon;
  final Color color;
  final VoidCallback? onAnimationComplete;

  const ThrowingKeyIcon({
    super.key,
    required this.visible,
    required this.icon,
    required this.color,
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
    if (!oldWidget.visible && widget.visible) {
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
      child: Icon(widget.icon, color: widget.color, size: 48),
    );
  }
}
