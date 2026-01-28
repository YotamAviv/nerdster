import 'package:flutter/material.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/io/source_factory.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/util_ui.dart';

class DumpAllStatements extends StatelessWidget {
  final TextEditingController controller = TextEditingController()..text = signInState.pov;
  final TextEditingController dropController = TextEditingController()..text = kOneofusDomain;

  static Future<void> show(BuildContext context) {
    return showDialog(
        context: context,
        builder: (BuildContext context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
            child: DumpAllStatements()));
  }

  DumpAllStatements({super.key});

  @override
  Widget build(BuildContext context) {
    DropdownMenu drop = DropdownMenu<String>(
      initialSelection: kOneofusDomain,
      requestFocusOnTap: true,
      label: const Text('Domain'),
      controller: dropController,
      dropdownMenuEntries: const [
        DropdownMenuEntry(value: kNerdsterDomain, label: kNerdsterDomain),
        DropdownMenuEntry(value: kOneofusDomain, label: kOneofusDomain)
      ],
    );

    return Padding(
        padding: kPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            drop,
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                  hintText: 'domain', hintStyle: hintStyle, border: OutlineInputBorder()),
              controller: controller,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                dump(dropController.text, controller.text);
              },
              child: const Text('dump (to console)'),
            ),
          ],
        ));
  }
}

Future<void> dump(String domain, String token) async {
  Map<String, List<Statement>> result = await SourceFactory.get(domain).fetch({token: null});
  Iterable<Statement> statements = result[token] ?? [];
  for (Statement statement in statements) {
    print('${statement.token} = ${statement.jsonish.ppJson}');
  }
}
