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
    return Material(
  color: Theme.of(context).colorScheme.surfaceContainer, // full-width bar color
  child: SizedBox(
    height: 40,
    width: double.infinity, // ensure the bar paints across the row
    child: Row(
      children: [
        MenuBar(
          // Let the Material’s color show through; MenuBar won't paint gray itself
          style: const MenuStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            elevation: WidgetStatePropertyAll(0),
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
          ),
          children: Menus.build(context),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Image.asset(
            'assets/images/nerd.png',
            height: 32,
          ),
        ),
      ],
    ),
  ),
);


  }
}
