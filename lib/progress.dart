import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/measure.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

abstract class ProgressR {
  void report(double p, String? message);
}

class ProgressRX extends ProgressR {
  final ValueNotifier<double> vn;
  ProgressRX(this.vn);
  @override
  void report(double p, String? message) {
    vn.value = p;
    progress.message.value = message;
  }
}

class ProgressDialog extends StatefulWidget {
  static final ProgressDialog singleton = ProgressDialog._internal();
  final ValueNotifier<double> oneofus = ValueNotifier(0);
  final ValueNotifier<double> nerdster = ValueNotifier(0);
  final ValueNotifier<String?> message = ValueNotifier(null);

  ProgressDialog._internal();

  factory ProgressDialog() => singleton;

  @override
  State<StatefulWidget> createState() => ProgressDialogState();

  Future<void> make(AsyncCallback func, BuildContext context) async {
    Measure.reset();
    try {
      // ignore: unawaited_futures
      _show(context);
      await func();
    } catch (e, stackTrace) {
      await alertException(context, e, stackTrace: stackTrace);
    } finally {
      Navigator.of(context).pop();
      Measure.dump();
    }
  }

  Future<void> _show(BuildContext context) async {
    oneofus.value = 0;
    nerdster.value = 0;
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
            child: Padding(
                padding: kPadding,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700, maxHeight: 200),
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
        Padding(padding: kPadding, child: LinearProgressIndicator(value: widget.oneofus.value)),
        const Text('''Loading nerster.org statements'''),
        Padding(padding: kPadding, child: LinearProgressIndicator(value: widget.nerdster.value)),
        if (b(widget.message.value)) Padding(padding: kPadding, child: Text(widget.message.value!)),
      ],
    );
  }

  void listen() => setState(() {});
}
