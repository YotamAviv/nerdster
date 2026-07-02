import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/logic/follow_logic.dart'
    show kFollowContextIdentity, kFollowContextNerdster;
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/ui/sign_in_widget.dart';

class TrustSettingsBar extends StatelessWidget {
  final List<IdentityKey> availableIdentities;
  final List<String> availableContexts;
  final Set<String> activeContexts;
  final Labeler labeler;

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
              if (!isSmall) ...[
                const Tooltip(
                  message: "Point of View",
                  child: Text('PoV: ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
              Flexible(
                flex: isSmall ? 2 : 5,
                child: Tooltip(
                  message: "Point of View",
                  child: ValueListenableBuilder<String?>(
                    valueListenable: signInState.povNotifier,
                    builder: (context, currentPov, _) {
                      assert(currentPov != null);
                      final String pov = currentPov!;
                      var items = [
                        ...availableIdentities.map((k) {
                          return DropdownMenuItem<String>(
                            value: k.value,
                            child: Text(
                              labeler.getIdentityLabel(k),
                              overflow: TextOverflow.ellipsis,
                              style: signInState.hasIdentity && signInState.identity == k
                                  ? const TextStyle(color: Colors.green)
                                  : null,
                            ),
                          );
                        }),
                        if (signInState.hasIdentity &&
                            availableIdentities.every((k) => k != signInState.identity))
                          DropdownMenuItem<String>(
                            value: signInState.identity.value,
                            child: Text(
                              '<identity>',
                              style: const TextStyle(color: Colors.green),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (availableIdentities.every((k) => k.value != pov) &&
                            (!signInState.hasIdentity || signInState.identity.value != pov))
                          DropdownMenuItem<String>(
                            value: pov,
                            child: Text(
                              labeler.getIdentityLabel(IdentityKey(pov)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ];
                      return DropdownButton<String>(
                        isExpanded: true,
                        value: pov,
                        hint: const Text('Select PoV', overflow: TextOverflow.ellipsis),
                        items: items,
                        isDense: true,
                        onChanged: (val) {
                          if (val != null) signInState.pov = val;
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isSmall) ...[
                const Tooltip(
                  message: 'Follow Context: Which follow network to use',
                  child: Text('Context: ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
              Flexible(
                flex: isSmall ? 2 : 4,
                child: Tooltip(
                  message: '''- <identity>: anyone who is someone
- <nerdster>: same as above with exceptions: follow/block to improve this network
- Other follow contexts (eg. music, news, family, ...): Use these if you have them, or create them''',
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
                                    child: Text(kFollowContextIdentity,
                                        overflow: TextOverflow.ellipsis)),
                                const DropdownMenuItem(
                                    value: kFollowContextNerdster,
                                    child: Text(kFollowContextNerdster,
                                        overflow: TextOverflow.ellipsis)),
                                ...availableContexts
                                    .where((c) =>
                                        c != kFollowContextIdentity && c != kFollowContextNerdster)
                                    .map((c) {
                                  final isContextActive = activeContexts.contains(c);
                                  return DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      overflow: TextOverflow.ellipsis,
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
                                  DropdownMenuItem(
                                      value: fcontext,
                                      child: Text(fcontext, overflow: TextOverflow.ellipsis)),
                              ],
                              isDense: true,
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
              const SizedBox(width: 4),
              const _DegreesControl(),
              const SizedBox(width: 4),
              const Flexible(
                flex: 0,
                child: SignInWidget(),
              ),
            ],
          );
        });
  }
}

/// Compact popover controlling how many degrees of separation from the point of
/// view to include in the follow network: 1 = only the PoV, 2 = the PoV and
/// those they follow directly, etc. See [SettingType.degrees].
///
/// The button is an outlined ring holding the current degree number. The ring
/// is drawn in the normal foreground colour when the PoV is included in the
/// network and greyed out when the PoV has been omitted ([SettingType.omitMe]).
class _DegreesControl extends StatefulWidget {
  const _DegreesControl();

  @override
  State<_DegreesControl> createState() => _DegreesControlState();
}

class _DegreesControlState extends State<_DegreesControl> {
  final MenuController _menuController = MenuController();

  // Live value while dragging the slider. We only commit to the setting (which
  // triggers a feed reload) on drag end, so dragging 6->1 causes one reload,
  // not one per intermediate value.
  int? _dragValue;

  @override
  Widget build(BuildContext context) {
    final Setting<int> degreesSetting = Setting.get<int>(SettingType.degrees);
    final Setting<bool> omitMeSetting = Setting.get<bool>(SettingType.omitMe);
    return ValueListenableBuilder<int>(
      valueListenable: degreesSetting.notifier,
      builder: (context, degrees, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: omitMeSetting.notifier,
          builder: (context, omitMe, __) {
            final bool includeMe = !omitMe;
            final int shown = _dragValue ?? degrees;
            return MenuAnchor(
              controller: _menuController,
              menuChildren: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SizedBox(
                    width: 280,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Degrees of separation: $shown',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Slider(
                          value: shown.toDouble(),
                          min: 1,
                          max: 6,
                          divisions: 5,
                          label: '$shown',
                          onChanged: (v) => setState(() => _dragValue = v.round()),
                          onChangeEnd: (v) {
                            setState(() => _dragValue = null);
                            degreesSetting.value = v.round();
                          },
                        ),
                        Text(
                          shown == 1
                              ? 'Only the point of view'
                              : 'The point of view and up to ${shown - 1} '
                                  'follow-hop${shown - 1 == 1 ? '' : 's'} away',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Divider(height: 16),
                        // Keeps the menu open (unlike MenuItemButton) so degrees
                        // and inclusion can be adjusted together.
                        InkWell(
                          onTap: () => omitMeSetting.value = !omitMeSetting.value,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  omitMe
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Flexible(
                                  child: Text('Hide my own contributions'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              builder: (context, controller, _) {
                final Color color = includeMe
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).disabledColor;
                return Tooltip(
                  message: includeMe
                      ? 'Follow network: $shown degree(s) from the point of view'
                      : 'Follow network: $shown degree(s) from the point of view, '
                          'excluding you',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 1.5),
                        ),
                        child: Text(
                          '$shown',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
