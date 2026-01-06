import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/interpreter.dart';

class CredentialsDisplay extends StatelessWidget {
  final Json? identityJson;
  final Json? delegateJson;
  final bool showDontShow;
  final ValueNotifier<bool> interpret = ValueNotifier(true);

  CredentialsDisplay(this.identityJson, this.delegateJson, {super.key, this.showDontShow = true});

  @override
  Widget build(BuildContext context) {
    Size whole = MediaQuery.of(context).size;
    double w = whole.width / 4;
    // make a little smaller
    w = w * 0.8;
    double h = min(w * 3 / 2, whole.height - 200);
    w = h * 2 / 3;

    return ValueListenableBuilder(
        valueListenable: globalLabeler,
        builder: (context, labeler, _) {
          final V2Interpreter? interpreter =
              signInState.pov != null ? V2Interpreter(labeler) : null;

          return SizedBox(
            width: w * 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Column(
                      children: [
                        Text('Identity'),
                        SizedBox(
                            width: w,
                            height: h,
                            child: JsonQrDisplay(identityJson,
                                interpret: interpret, interpreter: interpreter))
                      ],
                    ),
                    Column(
                      children: [
                        Text('Nerdster delegate'),
                        SizedBox(
                            width: w,
                            height: h,
                            child: JsonQrDisplay(delegateJson,
                                interpret: interpret, interpreter: interpreter))
                      ],
                    ),
                  ],
                ),
                if (showDontShow)
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    MyCheckbox(
                        Setting.get<bool>(SettingType.skipCredentials).notifier,
                        "Don't show again"),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.blue), // Mimic FAB
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        },
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    )
                  ]),
              ],
            ),
          );
        });
  }
}


class CredentialsWatcher extends StatefulWidget {
  final Widget child;
  const CredentialsWatcher({super.key, required this.child});

  @override
  State<CredentialsWatcher> createState() => _CredentialsWatcherState();
}

class _CredentialsWatcherState extends State<CredentialsWatcher> {
  String? _lastIdentity;
  String? _lastDelegate;

  @override
  void initState() {
    super.initState();
    // Do NOT initialize with current values so that we detect the "change" from null on startup.
    // _lastIdentity = signInState.identity;
    // _lastDelegate = signInState.delegate;
    signInState.addListener(_checkState);
    // Check initial state after first frame to show if needed
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkState());
  }

  @override
  void dispose() {
    signInState.removeListener(_checkState);
    super.dispose();
  }

  void _checkState() {
    final newIdentity = signInState.identity;
    final newDelegate = signInState.delegate;

    if (newIdentity == _lastIdentity && newDelegate == _lastDelegate) return;

    _lastIdentity = newIdentity;
    _lastDelegate = newDelegate;

    if (Setting.get<bool>(SettingType.skipCredentials).value) return;
    if (newIdentity == null) return;

    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.white,
        closeIconColor: Colors.black,
        content: DefaultTextStyle(
            style: const TextStyle(color: Colors.black),
            child: CredentialsDisplay(
                signInState.identityJson, signInState.delegatePublicKeyJson)),
        duration: const Duration(seconds: 5),
        showCloseIcon: false,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.only(left: size.width / 2, bottom: 20, right: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

