import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/follow_logic.dart' show kFollowContextIdentity, kFollowContextNerdster;
import 'package:nerdster/v2/labeler.dart';

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
    return ValueListenableBuilder<bool>(
        valueListenable: isSmall,
        builder: (context, isSmall, _) {
          return Row(
            children: [
              if (!isSmall)
                const Tooltip(
                  message: "Point of View",
                  child: Text('PoV: ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              Flexible(
                flex: 5,
                child: Tooltip(
                  message: "Point of View",
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
                            !availableIdentities.contains(IdentityKey(signInState.identity)))
                          DropdownMenuItem<String>(
                            value: signInState.identity,
                            child: Text('<identity>', style: const TextStyle(color: Colors.green)),
                          ),
                      ];
                      return DropdownButton<String>(
                        isExpanded: true,
                        value: currentPov ?? signInState.pov,
                        hint: const Text('Select PoV'),
                        items: items,
                        onChanged: (val) {
                          if (val != null) signInState.pov = val;
                        },
                      );
                    },
                  ),
                ),
              ),
              if (!isSmall) const SizedBox(width: 8),
              if (!isSmall)
                const Tooltip(
                  message: 'Follow Context: Which follow network to use',
                  child: Text('Context: ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              Flexible(
                flex: 4,
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
                                    value: kFollowContextIdentity,
                                    child: Text(kFollowContextIdentity)),
                                const DropdownMenuItem(
                                    value: kFollowContextNerdster,
                                    child: Text(kFollowContextNerdster)),
                                ...availableContexts
                                    .where((c) =>
                                        c != kFollowContextIdentity && c != kFollowContextNerdster)
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
            ],
          );
        });
  }
}
