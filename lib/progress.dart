import 'package:flutter/material.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/oneofus/measure.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

/// Thoughts...
/// 
/// Measure.mSync(f) is nice.
/// 
/// The thing that takes time is Fetcher.fetch, which does know
/// - token
/// - domain
/// but doesn't know
/// - degrees
/// 
/// GreedyBfsTrust does know degrees, tokens, too, but is not well suited to measure fetch time cleanly.
/// 
/// 
///  
///
/// NEXT: Now that we're getting detailed progress with token, we can measure time.
/// Plan:
/// Users (Comps) notify at start (0)
/// We start the stopwatch 
/// We restart stopwatch at every progress report
/// Users (Comps) notify at end (1)
/// We dump repott
/// 
/// CONSIDER: Code to skip this in tests.
/// The UI should initiate some kind of active Progress thing.
/// Comps can check that and report to it; otherwise, they can skip that code.
/// 
/// Progress.start can return a ProgressR
/// - Progres will add a row for that thing, presumably {ONE-OF-US, Nerd'ster}
/// Progress.end closes it
/// ProgressR.report asserts that it's active
abstract class ProgressR {
  // TODO: Use KeyLabels or OneofusLabels on message, or something less KLUEGY?
  void report(double p, String? token);
}

/// Follow contexts (<Nerdster> included) need to load the Nerdster statements
class Progress extends StatefulWidget {
  static final Progress singleton = Progress._internal();
  final Measure measure = Measure('_');
  final ValueNotifier<double> oneofus = ValueNotifier(0);
  final ValueNotifier<double> nerdster = ValueNotifier(0);
  final ValueNotifier<String?> message = ValueNotifier(null);
  Progress._internal();

  factory Progress() => singleton;

  @override
  State<StatefulWidget> createState() => ProgressState();

  Future<void> make(VoidCallback func, BuildContext context) async {
    if (measure.isRunning) return;
    try {
      // ignore: unawaited_futures
      _show(context);

      Measure.reset();
      measure.start();

      func();

      await Comp.waitOnComps([keyLabels, contentBase]);
    } catch (e, stackTrace) {
      await alertException(context, e, stackTrace: stackTrace);
    } finally {
      Navigator.of(context).pop();
      measure.stop();
      Measure.dump();
    }
  }

  // ProgressR start(String name) {

  // }

  Future<void> _show(BuildContext context) async {
    oneofus.value = 0;
    nerdster.value = 0;
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
        // if (b(widget.message.value)) const Text('''Activity'''),
        if (b(widget.message.value))
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(widget.message.value!)),
      ],
    );
  }

  void listen() => setState(() {});
}
