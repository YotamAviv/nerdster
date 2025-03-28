import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nerdster/menus.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

class NerdsterMenu extends StatefulWidget {
  static const NerdsterMenu _singleton = NerdsterMenu._internal();
  factory NerdsterMenu() => _singleton;
  const NerdsterMenu._internal();

  @override
  State<StatefulWidget> createState() => _NerdsterMenuState();
}

class _NerdsterMenuState extends State<NerdsterMenu> {
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
    return MenuBar(
        // style: const MenuStyle(alignment: Alignment.topRight,
        // backgroundColor: WidgetStatePropertyAll<Color>(Colors.white)),
        children: Menus.build(context));
  }
}
