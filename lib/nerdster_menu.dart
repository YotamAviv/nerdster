import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nerdster/menus.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';

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
    Setting.get<bool>(SettingType.dev).addListener(listen);
  }

  @override
  void dispose() {
    Setting.get<bool>(SettingType.dev).removeListener(listen);
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
    return IntrinsicHeight(
        child: Stack(children: [
      Row(children: [Expanded(child: MenuBar(children: Menus.build(context)))]),
      Align(
          alignment: Alignment.centerRight,
          child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Image.asset(
                'assets/images/nerd.png',
                height: 38, // tweak to taste; doesn't change MenuBar height
              )))
    ]));
  }
}
