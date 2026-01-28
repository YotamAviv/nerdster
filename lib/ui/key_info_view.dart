import 'package:flutter/material.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/ui/json_display.dart';
import 'package:nerdster/logic/interpreter.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/ui/json_qr_display.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nerdster/config.dart';
import 'package:oneofus_common/io.dart';

class KeyInfoView extends StatelessWidget {
  final Jsonish jsonish;
  final String domain;
  final StatementSource source;
  final Labeler labeler;

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
          child: JsonQrDisplay(jsonish.json,
              interpret: ValueNotifier(true), interpreter: NerdsterInterpreter(labeler)),
        ),
        _buildStatementsLink(context),
      ],
    );
  }

  Widget _buildStatementsLink(BuildContext context) {
    if (fireChoice != FireChoice.fake) {
      String? revokeAt;
      final token = jsonish.token;
      revokeAt = labeler.graph.replacementConstraints[IdentityKey(token)];

      final Uri uri = FirebaseConfig.makeSimpleUri(domain, jsonish.token, revokeAt: revokeAt);
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
            content:
                SingleChildScrollView(child: JsonDisplay(j, interpreter: NerdsterInterpreter(labeler))),
            actions: [
              TextButton(child: const Text('Okay'), onPressed: () => Navigator.of(context).pop())
            ]);
      },
    );
  }

  static Future<void> show(
    BuildContext context,
    String token,
    String domain, {
    TapDownDetails? details,
    required StatementSource source,
    required Labeler labeler,
    BoxConstraints? constraints,
  }) {
    final jsonish = Jsonish.find(token);
    if (jsonish == null) {
      throw Exception('KeyInfoView: Could not find JSON for token $token');
    }

    return showDialog(
        context: context,
        builder: (context) {
          double width = 300;
          if (constraints != null && constraints.maxWidth < width) {
            width = constraints.maxWidth;
          }
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

            // Also constrain to passed constraints if details were provided (popup)
            // But usually constraints are for dialog mode?
            // Let's apply constraints to the container size if applicable.
            // But width is currently fixed at 300.
            // If constraints.maxWidth is passed (e.g. 600), checking < 300 is weird.

            // The user asked to CONSTRAIN the popup to be not super wide.
            // If the popup is currently fixed at 300, it's not wide.
            // Ah, maybe the user wants to INCREASE it? Or user thinks it is wide?
            // "The popup is super wide. Constrain it."
            // Wait, if I am passing maxWidth: 600, but here width is 300...
            // It might be that the stack/material is not constrained.

            // Wait, look at the Dialog return path below.

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
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ConstrainedBox(
                  constraints:
                      constraints ?? const BoxConstraints(maxWidth: 600), // Default safeguard
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: KeyInfoView(
                          jsonish: jsonish, domain: domain, source: source, labeler: labeler),
                    ),
                  )));
        });
  }
}
