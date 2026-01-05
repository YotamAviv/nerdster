import 'package:flutter/material.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/v2/json_display.dart';
import 'package:nerdster/v2/interpreter.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nerdster/v2/config.dart';
import 'package:nerdster/v2/io.dart';

class KeyInfoView extends StatelessWidget {
  final Jsonish jsonish;
  final String domain;
  final StatementSource source;
  final V2Labeler labeler;

  const KeyInfoView({
    super.key, 
    required this.jsonish, 
    required this.domain,
    required this.labeler,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: JsonQrDisplay(jsonish.json, interpret: ValueNotifier(true), interpreter: V2Interpreter(labeler)),
        ),
        _buildStatementsLink(context),
      ],
    );
  }

  Widget _buildStatementsLink(BuildContext context) {
    if (fireChoice != FireChoice.fake) {
      String? revokeAt;
      final token = jsonish.token;
      revokeAt = labeler.graph.replacementConstraints[token];

      final Uri uri = V2Config.makeSimpleUri(domain, jsonish.token, revokeAt: revokeAt);
      return InkWell(
        onTap: () => launchUrl(uri),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Signed, Published Statements',
            style: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      return ElevatedButton.icon(
        icon: const Icon(Icons.library_books),
        label: const Text('View Published Statements (Fake)'),
        onPressed: () => _showFakeStatements(context),
      );
    }
  }

  Future<void> _showFakeStatements(BuildContext context) async {
    final map = await source.fetch({jsonish.token: null});
    final statements = map[jsonish.token] ?? [];
    List<dynamic> jsons = List.from(statements.map((s) => s.json));
    Map<String, dynamic> j = {jsonish.token: jsons};

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            title: const Text('Signed by this key'),
            content: SingleChildScrollView(child: V2JsonDisplay(j, interpreter: V2Interpreter(labeler))),
            actions: [
              TextButton(child: const Text('Okay'), onPressed: () => Navigator.of(context).pop())
            ]);
      },
    );
  }
  
  static Future<void> show(BuildContext context, String token, String domain,
      {TapDownDetails? details, required StatementSource source, required V2Labeler labeler}) {
    
    final jsonish = Jsonish.find(token);
    if (jsonish == null) {
      throw Exception('KeyInfoView: Could not find JSON for token $token');
    }

    return showDialog(
        context: context,
        builder: (context) {
          const double width = 300;
          const double height = 400;

          if (details != null) {
            final screenSize = MediaQuery.of(context).size;
            double left = details.globalPosition.dx;
            double top = details.globalPosition.dy;

            // Adjust to keep on screen
            if (left + width > screenSize.width) {
              left = screenSize.width - width - 10;
            }
            if (top + height > screenSize.height) {
              top = screenSize.height - height - 10;
            }

            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: kBorderRadius,
                        boxShadow: const [
                          BoxShadow(blurRadius: 10, color: Colors.black26)
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: KeyInfoView(
                            jsonish: jsonish, domain: domain, source: source, labeler: labeler),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Dialog(
              shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
              child: SizedBox(
                  width: width,
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: KeyInfoView(
                        jsonish: jsonish, domain: domain, source: source, labeler: labeler),
                  )));
        });
  }
}
