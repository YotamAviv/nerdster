import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

class NetBar extends StatefulWidget {
  // Rep invariant:
  // bNetView true: the NetTreeView MaterialPageRoute is pushed
  // bNetView false: not the above.
  // see NetTreeView.show()
  static final ValueNotifier<bool> bNetView = ValueNotifier<bool>(false);
  static final NetBar _singleton = NetBar._internal();
  factory NetBar() => _singleton;
  const NetBar._internal();

  @override
  State<NetBar> createState() => _NetBarState();


  static Future<void> showTree(BuildContext context) async {
    assert (!bNetView.value);
    // ignore: unawaited_futures
    NetTreeView.show(context);
  }

  static void setParams(Map<String, String> params) {
    if (bNetView.value) {
      params['netView'] = true.toString();
    }
  }
}

class _NetBarState extends State<NetBar> {
  @override
  void initState() {
    NetTreeView.bOneofus.addListener(listen);
    NetBar.bNetView.addListener(listen);
    super.initState();
  }

  @override
  void dispose() {
    NetTreeView.bOneofus.removeListener(listen);
    NetBar.bNetView.removeListener(listen);
    super.dispose();
  }

  void listen() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
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
          _StructureDropdown(NetBar.bNetView.value),
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
      DropdownMenuEntry(value: true, label: '<oneofus>'),
      DropdownMenuEntry(value: false, label: 'follow network'),
    ];

    const String message =
        '''"<one-of-us>" structure will build tree accoring to who one-of-us trusts whom.
If a follow context is selected, those included in the follow network will be green.

"follow network" structure will build the tee accoring to who follows whom for the selected context.''';

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
  const _CenterDropdown({super.key});

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
            (String fcontext) => DropdownMenuEntry<String?>(value: fcontext, label: fcontext))
        .toList();

    // Special null reset marker
    if (signInState.center != signInState.centerReset) {
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
      initialSelection: entries.first.label,
      label: const Text('Center'),
      onSelected: (String? value) {
        if (b(value)) {
          signInState.center = label2oneofus[value]!;
        } else {
          signInState.center = signInState.centerReset!;
        }
      },
    );
  }
}

// DEFER: singleton
class _FollowDropdown extends StatefulWidget {
  const _FollowDropdown({super.key});

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
    String initial = b(followNet.fcontext) ? followNet.fcontext! : '<one-of-us>';
    List<String> options = ['<one-of-us>', ...followNet.most];
    if (!options.contains(initial)) {
      options.add(initial);
    }
    List<DropdownMenuEntry<String?>> entries = options
        .map<DropdownMenuEntry<String>>((String fcontext) => DropdownMenuEntry<String>(
            value: fcontext,
            label: fcontext,
            enabled: followNet.centerContexts.contains(fcontext) || fcontext == '<one-of-us>'))
        .toList();

    bool error = !(followNet.centerContexts.contains(initial) || initial == '<one-of-us>');

    String message = error
        ? '''Center ("${keyLabels.labelKey(signInState.center)}") does not use the selected follow context ("$initial")}).
Select an enabled follow context or <one-of-us> (everyone).'''
        : '''Choose a follow context or <one-of-us> (everyone).''';

    return DropdownMenu<String?>(
      initialSelection: initial,
      // CONSIDER: https://pub.dev/packages/info_popup/example
      leadingIcon: Tooltip(
        message: message,
        child: Icon(
          Icons.help,
          color: error ? Colors.red : linkColor,
        ),
      ),
      label: const Text('Follow'),
      textStyle: error ? TextStyle(color: Colors.red) : null,
      onSelected: (String? fcontext) {
        if (fcontext != null) {
          followNet.fcontext = fcontext != '<one-of-us>' ? fcontext : null;
        }
        setState(() {});
      },
      dropdownMenuEntries: entries,
    );
  }
}
