import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:nerdster/util_ui.dart';

class DumpAllStatements extends StatelessWidget {
  final TextEditingController controller = TextEditingController()..text = SignInState().center;
  final TextEditingController dropController = TextEditingController()..text = kOneofusDomain;

  static Future<void> show(BuildContext context) {
    return showDialog(
        context: context,
        builder: (BuildContext context) => Dialog(child: DumpAllStatements()));
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
        padding: const EdgeInsets.all(15),
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
  Iterable<Statement> statements =
      await Fetcher(token, domain).fetchAllNoVerify();
  for (Statement statement in statements) {
    print('${statement.token} = ${statement.jsonish.ppJson}');
  }
}
