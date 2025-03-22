import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/oneofus/measure.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/singletons.dart';

/// Follow contexts (<Nerdster> included) need to load the Nerdster statements
class Progress extends StatefulWidget {
  static final Progress singleton = Progress._internal();
  final Measure measure = Measure('_');
  final ValueNotifier<double> oneofus = ValueNotifier(0);
  final ValueNotifier<double> nerdster = ValueNotifier(0);
  Progress._internal();

  factory Progress() => singleton;

  @override
  State<StatefulWidget> createState() => ProgressState();

  Future<void> make(VoidCallback func, BuildContext context) async {
    if (measure.isRunning) return;
    try {
      _show(context);
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   show(context);
      // });

      Measure.reset();
      measure.start();

      func();

      await Comp.waitOnComps([keyLabels]);
      await Comp.waitOnComps([contentBase]);
    } catch (e, stackTrace) {
      await alertException(context, e, stackTrace: stackTrace);
    } finally {
      // TEMP:
      Navigator.of(context).pop();
      measure.stop();
      Measure.dump();
    }
  }

  Future<void> _show(BuildContext context) async {
    oneofus.value = 0;
    nerdster.value = 0;
    // TODO: Wait 2 seconds before showing dialog
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => Dialog(
            child: Padding(
                padding: const EdgeInsets.all(15),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 700,
                      maxHeight: 200,
                    ),
                    child: singleton))));
  }
}

class ProgressState extends State<Progress> {
  @override
  void initState() {
    widget.oneofus.addListener(listen);
    widget.nerdster.addListener(listen);
    super.initState();
  }

  @override
  void dispose() {
    widget.oneofus.removeListener(listen);
    widget.nerdster.removeListener(listen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16.0,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('ONE-OF-US'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(value: widget.oneofus.value),
        ),
        const Text('''Nerd'ster'''),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(value: widget.nerdster.value),
        ),
      ],
    );
  }

  void listen() => setState(() {});
}
