import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nerdster/menus.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';

class NerdsterMenu extends StatefulWidget {
  final Widget v2Notifications;

  const NerdsterMenu({
    super.key,
    required this.v2Notifications,
  });

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
    return MenuBar(children: Menus.build(context, v2Notifications: widget.v2Notifications));
  }
}
