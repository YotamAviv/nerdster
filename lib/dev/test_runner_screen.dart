import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:nerdster/dev/cloud_source_suite.dart';
import 'package:flutter/scheduler.dart';

class TestRunnerScreen extends StatefulWidget {
  const TestRunnerScreen({super.key});

  @override
  State<TestRunnerScreen> createState() => _TestRunnerScreenState();
}

class _TestRunnerScreenState extends State<TestRunnerScreen> {
  String _status = "Initializing Tests...";
  bool _running = false;
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _runTests();
    });
  }

  void _log(String message) {
    debugPrint(message);
    setState(() {
      _status = message;
      logs.add(message);
    });
  }

  Future<void> _runTests() async {
    if (_running) return;
    _running = true;

    try {
      _log("Starting Integration Scenarios natively...");
      
      await runCloudSourceVerification();

      _log('All Permutations Verified!');
      _log('PASS');

    } catch (e, stack) {
      _log('ERROR: $e');
      _log('STACK TRACE: $stack');
      _log('FAIL');
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("DEV Auto-Test Runner")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return Text(logs[index], style: const TextStyle(fontFamily: 'monospace'));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
