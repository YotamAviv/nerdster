import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/follow/follow_net.dart' show kOneofusContext, kNerdsterContext;
import 'package:nerdster/v2/refresh_signal.dart';

class IdentityContextSelector extends StatelessWidget {
  final List<String> availableIdentities;
  final List<String> availableContexts;
  final Set<String> activeContexts;
  final V2Labeler labeler;

  const IdentityContextSelector({
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
        const Text('PoV: ', style: TextStyle(fontWeight: FontWeight.bold)),
        Flexible(
          flex: 3,
          child: ValueListenableBuilder<String?>(
            valueListenable: Setting.get<String?>(SettingType.pov).notifier,
            builder: (context, currentPov, _) {
              return DropdownButton<String>(
                isExpanded: true,
                value: (availableIdentities.contains(currentPov) || currentPov == signInState.pov)
                    ? currentPov
                    : null,
                hint: currentPov != null ? Text(labeler.getLabel(currentPov)) : const Text('Select PoV'),
                items: [
                  if (signInState.pov != null)
                    DropdownMenuItem(
                      value: signInState.pov!,
                      child: Text('Me (${labeler.getLabel(signInState.pov!)})'),
                    ),
                  ...availableIdentities
                      .where((k) => k != signInState.pov)
                      .map((k) {
                    return DropdownMenuItem(
                      value: k,
                      child: Text(labeler.getLabel(k)),
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val != null) {
                    Setting.get<String?>(SettingType.pov).value = val;
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        const Text('Context: ', style: TextStyle(fontWeight: FontWeight.bold)),
        Flexible(
          flex: 2,
          child: ValueListenableBuilder<String>(
            valueListenable: Setting.get<String>(SettingType.fcontext).notifier,
            builder: (context, fcontext, _) {
              final hasError = !activeContexts.contains(fcontext) &&
                  fcontext != kOneofusContext &&
                  fcontext != kNerdsterContext;

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
                        const DropdownMenuItem(value: kOneofusContext, child: Text(kOneofusContext)),
                        const DropdownMenuItem(value: kNerdsterContext, child: Text(kNerdsterContext)),
                        ...availableContexts
                            .where((c) => c != kOneofusContext && c != kNerdsterContext)
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
                        if (fcontext != kOneofusContext &&
                            fcontext != kNerdsterContext &&
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
        const SizedBox(width: 16),
        const Text('Req: ', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          flex: 2,
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
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => v2RefreshSignal.signal(),
          tooltip: 'Refresh',
        ),
      ],
    );
  }
}
