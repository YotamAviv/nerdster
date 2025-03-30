import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
/// TODO: Make elegant
/// - [Measure, Progress]... scattered reporting to both.
/// - time spent computing outside of the async fetch.
/// - async fetch separated enclosing mission (oneofusNet, followNet)
/// - verify is like async fetching in that it'd be nice to measure it
///
///
/// the parts are all here
/// Questions:
/// - Where to get the singleton or whatever resource to make compatible with phone app?
///   - Could be a static init on Fetcher.
///     could more progress from singletons.dart to main.dart
/// - What changes if/when BatchFetch happens?
///   - per token loading
///   - I still want measurements
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
  void report(double p, String? message, String? token);
  Future mAsync(func, {String? token});
  dynamic mSync(func, {String? token});
}

class ProgressRX extends ProgressR {
  @override
  void report(double p, String? message, String? token) {
    progress.nerdster.value = p;
    progress.message.value =
        (b(token) ? oneofusLabels.labelKey(token!) ?? token : '') + (message ?? '');
  }
  
  @override
  Future mAsync(func, {String? token}) {
    // TODO: implement mAsync
    throw UnimplementedError();
  }
  
  @override
  mSync(func, {String? token}) {
    // TODO: implement mSync
    throw UnimplementedError();
  }
}

/// Follow contexts (<Nerdster> included) need to load the Nerdster statements
class ProgressDialog extends StatefulWidget {
  static final ProgressDialog singleton = ProgressDialog._internal();
  final Measure measure = Measure('_');
  final ValueNotifier<double> oneofus = ValueNotifier(0);
  final ValueNotifier<double> nerdster = ValueNotifier(0);
  final ValueNotifier<String?> message = ValueNotifier(null);
  final LinkedHashMap<String, ProgressRX> pp = LinkedHashMap<String, ProgressRX>();

  ProgressDialog._internal();

  factory ProgressDialog() => singleton;

  @override
  State<StatefulWidget> createState() => ProgressDialogState();

  ProgressR create(String title) {
    assert(!pp.containsKey(title));
    ProgressRX p = ProgressRX();
    pp[title] = p;
    return p;
  }

  Future<void> make(AsyncCallback func, BuildContext context) async {
    if (measure.isRunning) return;
    try {
      // ignore: unawaited_futures
      _show(context);

      Measure.reset();
      measure.start();

      await func();

      // await Comp.waitOnComps([keyLabels, contentBase]);
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

class ProgressDialogState extends State<ProgressDialog> {
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
        const Text('Loading one-of-us.net statements'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(value: widget.oneofus.value),
        ),
        const Text('''Loading nerster.org statements'''),
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
