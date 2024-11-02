import 'package:flutter/material.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/net/oneofus_net.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

class NetBar extends StatefulWidget {
  const NetBar({super.key});

  @override
  State<NetBar> createState() => _NetBarState();
}

class _NetBarState extends State<NetBar> {
  @override
  void initState() {
    NetTreeView.bOneofus.addListener(listen);
    super.initState();
  }

  @override
  void dispose() {
    NetTreeView.bOneofus.removeListener(listen);
    super.dispose();
  }

  void listen() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // DEFER: If [FollowNet].fcontext is null, then we probably shouldn't -> to a 
    // follow network screen which is the same as the one-of-us network screen.
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[

          // <-- button
          if (NetTreeView.bOneofus.value) IconButton(
              icon: const Icon(Icons.arrow_back),
              color: linkColor,
              tooltip: 'Follow network view',
              onPressed: () {
                NetTreeView.bOneofus.value = false;
              }),
          if (!NetTreeView.bOneofus.value) IconButton(
              icon: const Icon(Icons.arrow_back),
              color: linkColor,
              tooltip: 'Content view',
              onPressed: () {
                Navigator.pop(context);
              }),

          const BarRefresh(),
          const FollowDropdown(),
          DropdownMenu<int>(
            initialSelection: 1,
            enabled: false,
            requestFocusOnTap: true,
            label: const Text('Paths'),
            onSelected: (int? paths) {
              setState(() {
                if (paths != null) {
                  OneofusNet().numPaths = paths;
                  setState(() => {});
                }
              });
            },
            dropdownMenuEntries: List.of(List<int>.generate(2, (i) => i + 1)
                .map((i) => DropdownMenuEntry<int>(value: i, label: i.toString()))),
          ),
          DropdownMenu<int>(
            initialSelection: 6,
            enabled: false,
            requestFocusOnTap: true,
            label: const Text('Degrees'),
            onSelected: (int? degrees) {
              setState(() {
                if (degrees != null) {}
              });
            },
            dropdownMenuEntries: List.of(List<int>.generate(6, (i) => i + 1)
                .map((i) => DropdownMenuEntry<int>(value: i, label: i.toString()))),
          ),

          // --> button
          if (!NetTreeView.bOneofus.value) IconButton(
              icon: const Icon(Icons.arrow_forward),
              color: linkColor,
              tooltip: 'one-of-us network view',
              onPressed: () {
                NetTreeView.bOneofus.value = true;
              }),

        ],
      ),
    );
  }
}

// DEFER: singleton
class FollowDropdown extends StatefulWidget {
  const FollowDropdown({super.key});

  @override
  State<StatefulWidget> createState() => _FollowDropdownState();
}

class _FollowDropdownState extends State<FollowDropdown> {
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
          .map<DropdownMenuEntry<String>>(
              (String fcontext) => DropdownMenuEntry<String>(value: fcontext, label: fcontext))
          .toList();
    return DropdownMenu<String?>(
      initialSelection: initial,
      // requestFocusOnTap is enabled/disabled by platforms when it is null.
      // On mobile platforms, this is false by default. Setting this to true will
      // trigger focus request on the text field and virtual keyboard will appear
      // afterward. On desktop platforms however, this defaults to true.
      // requestFocusOnTap: true,
      label: const Text('Follow'),
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
