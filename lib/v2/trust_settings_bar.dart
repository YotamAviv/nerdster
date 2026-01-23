import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/follow_logic.dart' show kFollowContextIdentity, kFollowContextNerdster;
import 'package:nerdster/v2/refresh_signal.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/v2/sign_in_widget.dart';

class TrustSettingsBar extends StatelessWidget {
  final List<IdentityKey> availableIdentities;
  final List<String> availableContexts;
  final Set<String> activeContexts;
  final V2Labeler labeler;

  const TrustSettingsBar({
    super.key,
    required this.availableIdentities,
    required this.availableContexts,
    required this.activeContexts,
    required this.labeler,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Tooltip(
          message: "Point of View",
          child: Text('PoV: ', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Flexible(
          flex: 3,
          child: ValueListenableBuilder<String?>(
            valueListenable: signInState.povNotifier,
            builder: (context, currentPov, _) {
              var items = [
                ...availableIdentities.map((k) {
                  return DropdownMenuItem<String>(
                    value: k.value,
                    child: Text(
                      labeler.getIdentityLabel(k),
                      style: signInState.identity == k.value
                          ? const TextStyle(color: Colors.green)
                          : null,
                    ),
                  );
                }),
                if (currentPov != null &&
                    signInState.identity != null &&
                    !availableIdentities.contains(IdentityKey(signInState.identity!)))
                  DropdownMenuItem<String>(
                    value: signInState.identity!.toString(),
                    child: Text('<identity>', style: const TextStyle(color: Colors.green)),
                  ),
              ];
              return DropdownButton<String>(
                isExpanded: true,
                value: currentPov,
                hint: const Text('Select PoV'),
                items: items,
                onChanged: (val) {
                  signInState.pov = val;
                },
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        const Tooltip(
          message: 'Follow Context: Which follow network to use',
          child: Text('Context: ', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Flexible(
          flex: 2,
          child: Tooltip(
            message: '''- <identity>: anyone who is someone
- <nerdster>: same as above with exceptions: follow/block to improve this network
- music, news, local, family, etc...: Use these if you have them, or create them''',
            child: ValueListenableBuilder<String>(
              valueListenable: Setting.get<String>(SettingType.fcontext).notifier,
              builder: (context, fcontext, _) {
                final hasError = !activeContexts.contains(fcontext) &&
                    fcontext != kFollowContextIdentity &&
                    fcontext != kFollowContextNerdster;

                return Row(
                  children: [
                    if (hasError)
                      const Tooltip(
                        message: 'This PoV does not use this follow context.',
                        child: Icon(Icons.error_outline, color: Colors.red, size: 16),
                      ),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: fcontext,
                        style: hasError ? const TextStyle(color: Colors.red) : null,
                        items: [
                          const DropdownMenuItem(
                              value: kFollowContextIdentity, child: Text(kFollowContextIdentity)),
                          const DropdownMenuItem(
                              value: kFollowContextNerdster, child: Text(kFollowContextNerdster)),
                          ...availableContexts
                              .where(
                                  (c) => c != kFollowContextIdentity && c != kFollowContextNerdster)
                              .map((c) {
                            final isContextActive = activeContexts.contains(c);
                            return DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: TextStyle(
                                  color: isContextActive ? null : Colors.grey,
                                  fontStyle: isContextActive ? null : FontStyle.italic,
                                ),
                              ),
                            );
                          }),
                          if (fcontext != kFollowContextIdentity &&
                              fcontext != kFollowContextNerdster &&
                              !availableContexts.contains(fcontext))
                            DropdownMenuItem(value: fcontext, child: Text(fcontext)),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            Setting.get<String>(SettingType.fcontext).value = val;
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Tooltip(
          message: 'Require more redundant paths to detect and prevent fraud',
          child: Text('Confidence: ', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 2,
          child: Tooltip(
            message: 'Slide to adjust trust strictness (Permissive, Standard, Strict)',
            child: ValueListenableBuilder<String>(
              valueListenable: Setting.get<String>(SettingType.identityPathsReq).notifier,
              builder: (context, req, _) {
                double sliderValue = 1.0;
                if (req == 'permissive') sliderValue = 0.0;
                if (req == 'strict') sliderValue = 2.0;

                return Slider(
                  value: sliderValue,
                  min: 0,
                  max: 2,
                  divisions: 2,
                  label: req,
                  onChanged: (val) {
                    String newReq = 'standard';
                    if (val == 0.0) newReq = 'permissive';
                    if (val == 2.0) newReq = 'strict';
                    Setting.get<String>(SettingType.identityPathsReq).value = newReq;
                  },
                );
              },
            ),
          ),
        ),
        Tooltip(
          message: 'Refresh the feed',
          child: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => v2RefreshSignal.signal(),
          ),
        ),
        const SizedBox(width: 8),
        const SignInWidget(),
      ],
    );
  }
}
