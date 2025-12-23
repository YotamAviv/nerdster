import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/credentials_display.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/json_highlighter.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';

/// from: https://www.urlencoder.org/
/// ?verify=%0A%7B%0A%20%20%22statement%22%3A%20%22org.nerdster%22%2C%0A%20%20%22time%22%3A%20%222025-07-03T14%3A11%3A25.901Z%22%2C%0A%20%20%22I%22%3A%20%7B%0A%20%20%20%20%22crv%22%3A%20%22Ed25519%22%2C%0A%20%20%20%20%22kty%22%3A%20%22OKP%22%2C%0A%20%20%20%20%22x%22%3A%20%22qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI%22%0A%20%20%7D%2C%0A%20%20%22rate%22%3A%20%7B%0A%20%20%20%20%22contentType%22%3A%20%22book%22%2C%0A%20%20%20%20%22author%22%3A%20%22Ring%20Lardner%22%2C%0A%20%20%20%20%22title%22%3A%20%22Champion%22%0A%20%20%7D%2C%0A%20%20%22with%22%3A%20%7B%0A%20%20%20%20%22recommend%22%3A%20true%0A%20%20%7D%2C%0A%20%20%22comment%22%3A%20%22A%20long-form%20cynical%20joke%2C%20fantastic%20counterpoint%20dessert%20piece%20to%20%5C%22Ghosts%20of%20Manila%5C%22%2C%20a%2020%20page%20setup%20to%20punch%20line%20%28no%20pun%20intended%29.%22%2C%0A%20%20%22previous%22%3A%20%226282a02d21eff999e0a3a9216a087f7a4ce79d0c%22%2C%0A%20%20%22signature%22%3A%20%22276f15ca9c32a02fcaaaec68019df09a0768ab7cd0109723811df4d7eda313fdd10afeee8a9dcf3f368f238dc2fc7543c671f3f9d855ba82573c0723ce84a107%22%0A%7D

OouVerifier _oouVerifier = OouVerifier();

const String kVerify = 'Verify, Tokenize';
const Widget _space = SizedBox(height: 20);

Widget headline(String text) => Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
final TextStyle monospaceStyle =
    GoogleFonts.courierPrime(fontWeight: FontWeight.w700, fontSize: 13);
Widget monospacedBlock(String text) => SelectableText.rich(
      TextSpan(
          children: highlightJsonKeys(text, monospaceStyle, keysToHighlight: Verify.highlightKeys)),
    );

class Verify extends StatefulWidget {
  static Set<String> highlightKeys = {};
  final String? input;

  const Verify({super.key, this.input});

  @override
  State<Verify> createState() => _VerifyState();
}

void verifyInit(GlobalKey<NavigatorState> navigatorKey) {
  Setting verifySetting = Setting.get(SettingType.verify);
  BuildContext? dialogContext;

  Future<void> handleVerify() async {
    final String? value = verifySetting.value;

    if (dialogContext != null) {
      if (dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
      dialogContext = null;
    }

    if (!b(value)) return;

    dismissCredentials();

    // Wait for navigator to be ready if needed
    if (navigatorKey.currentContext == null) {
      // This might happen on startup.
      // We can retry or wait for the first frame.
      // But since we are calling this from main(), runApp() is called right after.
      // So we can use addPostFrameCallback on the binding?
      // But we don't have a context yet.
      // Let's just wait a bit? No, that's hacky.
      // Better: use WidgetsBinding.instance.addPostFrameCallback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleVerify();
      });
      return;
    }

    final context = navigatorKey.currentContext!;

    print('${SettingType.verify.name}.value: $value');
    await showDialog(
        context: context,
        builder: (context) {
          dialogContext = context;
          return Dialog(
              // Doesn't work: shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
              child: Navigator(onGenerateRoute: (settings) {
            return MaterialPageRoute(
                builder: (_) => Verify(input: value));
          }));
        });
    dialogContext = null;
    verifySetting.value = null;
  }

  // Listen for changes
  verifySetting.addListener(handleVerify);

  // Check the value immediately
  handleVerify();
}

class _VerifyState extends State<Verify> {
  late final TextEditingController _controller;
  late String _initialText;

  @override
  void initState() {
    super.initState();
    _initialText = widget.input ?? '';
    _controller = TextEditingController(text: _initialText);

    _controller.addListener(() {
      setState(() {}); // Trigger rebuild to show/hide reset button
    });

    final bool verifyImmediately = Setting.get<bool>(SettingType.verifyImmediately).value;
    if (verifyImmediately && _initialText.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProcessedScreen(_controller.text),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasChanged => b(widget.input) && _controller.text != _initialText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo[700],
        centerTitle: true,
        actions: [
          if (_hasChanged)
            IconButton(
              tooltip: 'Reset to original text',
              onPressed: () {
                _controller.text = _initialText;
              },
              icon: Row(
                children: const [
                  Icon(Icons.refresh, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Reset', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          IconButton(
            tooltip: 'Verify and tokenize input',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProcessedScreen(_controller.text),
                ),
              );
            },
            icon: Row(
              children: const [
                Text('Verify, Tokenize', style: TextStyle(color: Colors.white)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText:
                      'JSON text to process. Use Ctrl-C / Ctrl-V to copy / paste, Ctrl-A to select all.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                style: monospaceStyle,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                controller: _controller,
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: headline('Signature verification and tokenizing'),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '''Expected fields:
  • "I" — a JWK (JSON Web Key) object representing the signer's public key
  • "signature" — a base64url-encoded signature

The process will:
1. Normalize the JSON input: 
  - Order the fields (statement, time, I, [verb], ..., signature)
  - Format using 2 space indentation
2. Verify:
  - Extract and decode the public key from field "I" (if present)
  - Extract the signature from field "signature" (if present)
  - Validate the full JSON content excluding the signature using the public key and signature (both must be present)
3. Tokenize: Compute the SHA1 hash of the normalized JSON.
4. Interpret: Display names in place of public keys, strip or convert values for readability''',
                                textAlign: TextAlign.left,
                                style: TextStyle(fontSize: 13.5),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProcessedScreen extends StatefulWidget {
  final String input;
  const ProcessedScreen(this.input, {super.key});

  @override
  State<ProcessedScreen> createState() => _ProcessedScreenState();
}

class _ProcessedScreenState extends State<ProcessedScreen> {
  String? _status;
  Color? _statusColor;

  void _updateStatus(String status, Color color) {
    setState(() {
      _status = status;
      _statusColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _statusColor ?? Colors.grey[800],
        title: Text(_status ?? 'Processing...', style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: ProcessedPanel(widget.input, onStatusChange: _updateStatus),
    );
  }
}

class ProcessedPanel extends StatefulWidget {
  final String input;
  final void Function(String status, Color color)? onStatusChange;

  const ProcessedPanel(this.input, {super.key, this.onStatusChange});

  @override
  State<ProcessedPanel> createState() => _ProcessedPanelState();
}

class _ProcessedPanelState extends State<ProcessedPanel> {
  Widget? _body;

  @override
  void initState() {
    super.initState();
    keyLabels.addListener(_onKeyLabelsChanged);
    _startProcessing();
  }

  @override
  void dispose() {
    keyLabels.removeListener(_onKeyLabelsChanged);
    super.dispose();
  }

  void _onKeyLabelsChanged() {
    _startProcessing();
  }

  void _set(Widget child) {
    if (mounted) setState(() => _body = child);
  }

  void _notifyStatus(String label, Color color) {
    Future.microtask(() {
      widget.onStatusChange?.call(label, color);
    });
  }

  Future<void> _startProcessing() async {
    await Comp.waitOnComps([keyLabels]);
    if (!mounted) return;

    final input = widget.input;
    Json json;

    try {
      json = jsonDecode(input);
    } catch (e) {
      _notifyStatus('INVALID JSON', Colors.red[700]!);
      _set(_error([
        headline('Failed to parse JSON'),
        monospacedBlock('$e'),
      ]));
      return;
    }

    final children = <Widget>[];

    if (json.containsKey('id')) {
      json.remove('id');
      children.addAll([
        _space,
        headline('Stripped "id" (server computed token, not part of the statement)'),
      ]);
    }

    final Json ordered = Jsonish.order(json);
    final String ppJson = encoder.convert(ordered);
    final bool differs = ppJson.trim() != input.trim();
    if (differs) {
      children.addAll([
        _space,
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: headline('Formatted JSON (2 spaces)'),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: monospacedBlock(ppJson),
            ),
          ],
        ),
      ]);
    }

    OouPublicKey? iKey;
    if (json.containsKey('I')) {
      try {
        iKey = await crypto.parsePublicKey(json['I']!);
      } catch (e) {
        _notifyStatus('INVALID', Colors.red[700]!);
        _set(_error([
          headline('Error parsing public key "I"'),
          monospacedBlock('$e'),
        ]));
        return;
      }
    }

    final String? signature = json['signature'];

    if ((signature != null && iKey == null) || (signature == null && iKey != null)) {
      _notifyStatus('INVALID', Colors.red[700]!);
      _set(_error([
        headline('Invalid statement'),
        monospacedBlock(
            'Both "signature" and "I" (author\'s public key) must be present together, or neither.'),
      ]));
      return;
    }

    if (signature != null && iKey != null) {
      final withoutSig = Map.from(ordered)..remove('signature');
      final String jsonWithoutSig = encoder.convert(withoutSig);
      final verified = await _oouVerifier.verify(json, jsonWithoutSig, signature);

      if (verified) {
        _notifyStatus('✔ VERIFIED!', Colors.green[700]!);
        children.addAll([
          _space,
          headline('✔ Verified'),
          monospacedBlock('Signature successfully verified.'),
        ]);
      } else {
        _notifyStatus('✘ INVALID SIGNATURE', Colors.red[700]!);
        children.addAll([_space, headline('✘ Signature verification FAILED!')]);
        // Do continue and interpret regardless return;
      }
    } else {
      _notifyStatus('Not signed', Colors.grey[700]!);
    }

    final String interpreted = encoder.convert(keyLabels.interpret(json));
    if (interpreted != ppJson) {
      children.addAll([
        _space,
        headline('Interpreted'),
        monospacedBlock(interpreted),
      ]);
    }

    final String token = sha1.convert(utf8.encode(ppJson)).toString();
    children.addAll([
      _space,
      headline('Tokenized'),
      monospacedBlock(token),
    ]);

    _set(Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _body != null
        ? ListView(
            padding: const EdgeInsets.all(16),
            children: [_body!],
          )
        : const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
  }

  Widget _error(List<Widget> content) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: content),
      );
}

class StandaloneVerify extends StatelessWidget {
  const StandaloneVerify({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: Setting.get(SettingType.verify),
      builder: (context, value, child) {
        return Verify(
          key: ValueKey(value),
          input: value,
        );
      },
    );
  }
}
