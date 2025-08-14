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
    return SizedBox(
      width: double.infinity, // full width, like production
      child: IntrinsicHeight(
        // gives Stack a finite height based on MenuBar
        child: Stack(
          children: [
            // Base layout: MenuBar stretches to full width
            Row(children: [Expanded(child: MenuBar(children: Menus.build(context)))]),
            // Right-edge Nerdster image, overlaid (doesn't affect MenuBar layout)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                  child: Image.asset(
                'assets/images/nerd.png',
                height: 38, // tweak to taste; doesn’t change MenuBar’s height
              )),
            )
          ],
        ),
      ),
    );
  }
}
