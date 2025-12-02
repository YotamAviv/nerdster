import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/pop_state_stub.dart'
    if (dart.library.js_interop) 'package:nerdster/ui/pop_state_web.dart';
import 'package:nerdster/util_ui.dart';

class NetBar extends StatefulWidget {
  // Rep invariant: (exception for when loading and reacting to param settings)
  // bNetView true: the NetTreeView MaterialPageRoute is pushed
  // bNetView false: not the above.
  // see NetTreeView.show()
  static final ValueNotifier<bool> bNetView = Setting.get<bool>(SettingType.netView).notifier;
  static final NetBar _singleton = NetBar._internal();
  factory NetBar() => _singleton;
  const NetBar._internal();

  @override
  State<NetBar> createState() => _NetBarState();

  static Future<void> showTree(BuildContext context) async {
    await NetTreeView.show(context);
  }
}

class _NetBarState extends State<NetBar> {
  static int instanceCount = 0;

  late final StreamSubscription<void> _popStateSub;

  @override
  void initState() {
    instanceCount++;
    // print(instanceCount);

    NetTreeView.bOneofus.addListener(listen);
    NetBar.bNetView.addListener(listen);
    isSmall.addListener(listen);

    final listenerId = DateTime.now().microsecondsSinceEpoch;
    if (NetBar.bNetView.value) {
      _popStateSub = bindPopState(() {
        setState(() {
          // TODO: Clean up these prints, listenerId, and instanceCount once I feel confident.
          // print('Back button pressed from listener $listenerId');
          NetBar.bNetView.value = false;
        });
      });
    }

    super.initState();
  }

  @override
  void dispose() {
    instanceCount--;
    // print(instanceCount);

    NetTreeView.bOneofus.removeListener(listen);
    NetBar.bNetView.removeListener(listen);
    isSmall.removeListener(listen);
    // print('Disposing MyWidgetState');
    _popStateSub.cancel();
    super.dispose();
  }

  void listen() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 12, 0, 4), // kTallPadding not tall enough
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // <-- button
          if (NetBar.bNetView.value)
            IconButton(
                icon: const Icon(Icons.arrow_back),
                color: linkColor,
                tooltip: 'Content view',
                onPressed: () {
                  Navigator.pop(context);
                  NetBar.bNetView.value = false;
                }),
          const BarRefresh(),
          const _CenterDropdown(),
          const _FollowDropdown(),
          if (!isSmall.value) _StructureDropdown(NetBar.bNetView.value),
          if (!NetBar.bNetView.value)
            IconButton(
                icon: const Icon(Icons.arrow_forward),
                color: linkColor,
                tooltip: 'Network view',
                onPressed: () async {
                  await NetBar.showTree(context);
                }),
        ],
      ),
    );
  }
}

class _StructureDropdown extends StatefulWidget {
  final bool bContent;
  const _StructureDropdown(this.bContent);

  @override
  State<StatefulWidget> createState() => _StructureDropdownState();
}

class _StructureDropdownState extends State<_StructureDropdown> {
  @override
  void initState() {
    super.initState();
    NetTreeView.bOneofus.addListener(listener);
  }

  @override
  void dispose() {
    NetTreeView.bOneofus.removeListener(listener);
    super.dispose();
  }

  void listener() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<DropdownMenuEntry> entries = [
      DropdownMenuEntry(value: true, label: '<one-of-us>'),
      DropdownMenuEntry(value: false, label: 'follow network'),
    ];

    const String message =
        '''"<one-of-us>" structure will build tree accoring to who one-of-us trusts whom.
In case statements are displayed, they'll be identity statements.

"follow network" structure will build the tree accoring to who follows whom for the selected context.
In case statements are displayed, they'll be follow statements.

People included in the follow network are displayed in green.''';

    bool enabled = widget.bContent;

    return DropdownMenu(
      enabled: enabled,
      leadingIcon: Tooltip(
        message: message,
        child: Icon(
          Icons.help,
          color: enabled ? linkColor : linkColorDisabled,
        ),
      ),
      label: const Text('Tree structure'),
      initialSelection: NetTreeView.bOneofus.value,
      dropdownMenuEntries: entries,
      onSelected: (bOneofus) {
        NetTreeView.bOneofus.value = bOneofus;
      },
    );
  }
}

class _CenterDropdown extends StatefulWidget {
  const _CenterDropdown();

  @override
  State<StatefulWidget> createState() => _CenterDropdownState();
}

class _CenterDropdownState extends State<_CenterDropdown> {
  @override
  initState() {
    super.initState();
    signInState.addListener(listen);
    keyLabels.addListener(listen);
    listen();
  }

  @override
  dispose() {
    signInState.removeListener(listen);
    keyLabels.removeListener(listen);
    super.dispose();
  }

  void listen() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!Comp.compsReady([oneofusNet, keyLabels, followNet])) {
      // I'm not confident about this.
      // print('loading..');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        listen();
      });
      return const Text('Loading..');
    }

    Map<String, String> label2oneofus = <String, String>{};
    for (String oneofus in followNet.oneofus2delegates.keys) {
      String label = keyLabels.labelKey(oneofus)!;
      label2oneofus[label] = oneofus;
    }

    List<DropdownMenuEntry<String?>> entries = label2oneofus.keys
        .map<DropdownMenuEntry<String?>>(
            (String s) => DropdownMenuEntry<String?>(value: s, label: s))
        .toList();
    if (!b(signInState.pov)) entries = [DropdownMenuEntry<String?>(value: 'N/A', label: 'N/A')];

    // Special null reset marker
    if (signInState.pov != signInState.identity && b(signInState.identity)) {
      DropdownMenuEntry<String?> reset = DropdownMenuEntry<String?>(value: null, label: '<reset>');
      entries.add(reset);
      // TODO: Put <reset> at top instead of bottom.
      // entries.insert(0, reset);
    }

    return DropdownMenu<String?>(
      dropdownMenuEntries: entries,
      // Kudos: https://stackoverflow.com/questions/77123848/flutter-dart-dropdownmenu-doesnt-update-when-i-call-a-setstate-and-modify-my-lo
      // Without key: UniqueKey(), the selected value does not update correctly.
      key: UniqueKey(),
      requestFocusOnTap: false,
      enableFilter: false,
      enableSearch: false,
      initialSelection: entries.isNotEmpty ? entries.first.label : null,
      label: const Text('PoV'),
      onSelected: (String? value) async {
        // NEXT: progress listen to signInState.center
        await progress.make(() async {
          signInState.pov = b(value) ? label2oneofus[value]! : signInState.identity;
          await Comp.waitOnComps([keyLabels, contentBase]);
        }, context);
      },
    );
  }
}

// DEFER: singleton
class _FollowDropdown extends StatefulWidget {
  const _FollowDropdown();

  @override
  State<StatefulWidget> createState() => _FollowDropdownState();
}

class _FollowDropdownState extends State<_FollowDropdown> {
  @override
  void initState() {
    super.initState();
    followNet.addListener(listen);
    listen();
  }

  void listen() async {
    await Comp.waitOnComps([followNet]);
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    followNet.removeListener(listen);
  }

  @override
  Widget build(BuildContext context) {
    // The issue was that the Dropdown showed its label inside when initial wasn't one of the options.
    String initial = followNet.fcontext;
    List<String> options = [kNerdsterContext, kOneofusContext, ...followNet.most];
    if (!options.contains(initial)) {
      options.add(initial);
    }
    List<DropdownMenuEntry<String?>> entries = options
        .map<DropdownMenuEntry<String>>((String fcontext) => DropdownMenuEntry<String>(
            value: fcontext,
            label: fcontext,
            enabled:
                followNet.centerContexts.contains(fcontext) || kSpecialContexts.contains(fcontext)))
        .toList();

    bool error =
        !(followNet.centerContexts.contains(initial) || kSpecialContexts.contains(initial));

    String center = b(signInState.pov) ? ("${keyLabels.labelKey(signInState.pov!)}") : 'This PoV';
    String message = error
        ? '''$center does not use the selected follow context ("$initial")}).
Select an enabled follow context or <one-of-us> (everyone).'''
        : '''Choose a follow context:
- <one-of-us>: everyone
- <nerdster>: everyone with exceptions (block folks that talk too much or specifically <nerdster> follow those far on your one-of-us network that you want closer)
- Custom contexts like 'nerd', 'social', 'family', 'local', 'geezer', etc...''';

    Slider degreesSlider = Slider(
        value: Setting.get<int>(SettingType.followNetDegrees).value as double,
        min: 1.0,
        max: 6.0,
        divisions: 4,
        label: 'Degrees: ${Setting.get<int>(SettingType.followNetDegrees).value}',
        thumbColor: Colors.green,
        onChanged: (x) {
          print(x);
          setState(() {
            Setting.get<int>(SettingType.followNetDegrees).value = x.round();
          });
        });
    DropdownMenuEntry<String> degreesDropdownEntry = DropdownMenuEntry(
      // labelWidget: Row(children: [const Text('Degrees:'), degreesSlider]);
      labelWidget: SizedBox(width: 50, child: degreesSlider),
      // labelWidget: degreesSlider,
      enabled: false,
      value: '',
      label: '',
    );

    return DropdownMenu<String?>(
      initialSelection: initial,
      // CONSIDER: https://pub.dev/packages/info_popup/example
      leadingIcon: Tooltip(
        message: message,
        child: Icon(Icons.help, color: error ? Colors.red : linkColor),
      ),
      label: const Text('Follow context'),
      textStyle: error ? TextStyle(color: Colors.red) : null,
      onSelected: (String? fcontext) async {
        await progress.make(() async {
          followNet.fcontext = fcontext!;
          await Comp.waitOnComps([keyLabels, contentBase]);
        }, context);
        setState(() {});
      },
      dropdownMenuEntries: [degreesDropdownEntry, ...entries],
    );
  }
}
