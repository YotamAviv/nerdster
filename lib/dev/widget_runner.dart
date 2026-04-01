import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class WidgetRunner extends StatefulWidget {
  final Future<void> Function() scenario;

  const WidgetRunner({super.key, required this.scenario});

  @override
  State<WidgetRunner> createState() => _WidgetRunnerState();
}

class _WidgetRunnerState extends State<WidgetRunner> {
  bool _running = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _runTests();
    });
  }

  void _log(String message) {
    // Write directly to flutter standard output so the python script can intercept it
    debugPrint(message); 
  }

  Future<void> _runTests() async {
    if (_running) return;
    _running = true;

    try {
      _log("Starting Widget Runner execution...");
      await widget.scenario();
      _log("Widget Runner completed scenario successfully.");
    } catch (e, stack) {
      _log('TEST FAILED WITH ERROR: $e');
      _log('STACK TRACE: $stack');
      _log('Some tests failed.');
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "Widget Runner Active - See Terminal Output",
            style: TextStyle(color: Colors.green),
          ),
        ),
      ),
    );
  }
}
