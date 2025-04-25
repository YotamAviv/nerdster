import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/menus.dart';
import 'package:nerdster/net/net_bar.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

class NetMenu extends StatefulWidget {
  static const NetMenu _singleton = NetMenu._internal();
  factory NetMenu() => _singleton;
  const NetMenu._internal();

  @override
  State<StatefulWidget> createState() => _NetMenuState();
}

class _NetMenuState extends State<NetMenu> {
  get backgroundColor => null;

  @override
  void initState() {
    super.initState();
    Prefs.dev.addListener(listen);
    signInState.addListener(listen);
  }

  @override
  void dispose() {
    Prefs.dev.removeListener(listen);
    signInState.removeListener(listen);
    super.dispose();
  }

  void listen() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> ws = [
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
      const CenterDropdown(),
      const FollowDropdown(),
      StructureDropdown(NetBar.bNetView.value),
      if (!NetBar.bNetView.value)
        IconButton(
            icon: const Icon(Icons.arrow_forward),
            color: linkColor,
            tooltip: 'Network view',
            onPressed: () async {
              await NetBar.showTree(context);
            }),
    ];

    return MenuBar(
        style: MenuStyle(
          // backgroundColor: WidgetStateProperty.all(Colors.white),
          shadowColor: WidgetStateProperty.all(Colors.white),
          // surfaceTintColor,
          // elevation,
          padding: WidgetStateProperty.all(EdgeInsets.all(20.0)),
          // minimumSize,
          // fixedSize,
          // maximumSize,
          // side,
          // shape,
          // mouseCursor,
          // visualDensity,
        ),
        children: ws);
  }
}
