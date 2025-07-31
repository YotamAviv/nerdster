import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

enum Follow {
  follow('Follow', Colors.green, 1),
  block('Block', Colors.red, -1);

  final String label;
  final Color color;
  final int intValue;
  const Follow(this.label, this.color, this.intValue);
}

Future<Statement?> follow(String token, BuildContext context) async {
  if (await checkSignedIn(context) != true) return null;

  ContentStatement? priorStatement;
  for (ContentStatement s in followNet.getStatements(signInState.centerReset!)) {
    if (s.subjectToken == token) {
      priorStatement = s;
    }
  }
  Json contextsIn;
  if (b(priorStatement)) {
    contextsIn = priorStatement!.contexts!;
  } else {
    contextsIn = {
      'social': 1,
    };
  }
  Json? contextsOut = await showFollowDialog(token, contextsIn, context);
  if (contextsOut != null) {
    Json subjectPublicKey = Jsonish.find(token)!.json;
    Json json = ContentStatement.make(
        signInState.signedInDelegatePublicKeyJson!, ContentVerb.follow, subjectPublicKey,
        contexts: contextsOut);
    Statement? statement = await contentBase.insert(json, context);
    followNet.listen();
    return statement;
  }
  return null;
}

Future<Json?> showFollowDialog(String token, Json contextsIn, BuildContext context) async {
  return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
            shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
            child: Padding(
              padding: kTallPadding,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 400,
                  ),
                  child: FollowUi(contextsIn)),
            ));
      });
}

class FollowUi extends StatefulWidget {
  final Json contextsIn;

  const FollowUi(this.contextsIn, {super.key});

  @override
  State<StatefulWidget> createState() => _FollowUiState();
}

class _FollowUiState extends State<FollowUi> {
  final Map<String, FollowWidget> widgets = <String, FollowWidget>{};
  final TextEditingController controller = TextEditingController();

  _FollowUiState();

  @override
  initState() {
    super.initState();
    for (MapEntry e in widget.contextsIn.entries) {
      widgets[e.key] = FollowWidget(FollowWidget.i2follow[e.value]!);
    }
  }

  @override
  dispose() {
    controller.dispose();
    super.dispose();  
  }

  Future<void> make() async {
    Json contexts = {};
    for (MapEntry e in widgets.entries) {
      int i = e.value.followNotifier.value == Follow.follow ? 1 : -1;
      contexts[e.key] = i;
    }
    Navigator.pop(context, contexts);
  }

  @override
  Widget build(BuildContext context) {
    List<String> dropdownContexts = [];
    dropdownContexts.add(kNerdsterContext);
    dropdownContexts.addAll(followNet.most);
    dropdownContexts.addAll(['social', 'nerd']);
    dropdownContexts.removeWhere((c) => widgets.keys.contains(c));

    List<Row> rows = <Row>[];
    for (MapEntry e in widgets.entries) {
      Row row = Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        SizedBox(width: 80, child: Text(e.key)),
        e.value,
        IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              widgets.remove(e.key);
              setState(() {});
            }),
      ]);
      rows.add(row);
    }

    return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InputDecorator(
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                labelText: 'Follow contexts',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0)),
              ),
              child: Column(children: rows)),
          const SizedBox(height: 5),
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Add a follow context: '),
                DropdownMenu<String>(
                  controller: controller,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp("[a-z]"))],
                  requestFocusOnTap: true,
                  onSelected: (String? s) {
                    setState(() {
                      if (controller.text.isNotEmpty) {
                        widgets[controller.text] = FollowWidget(Follow.follow);
                        controller.text = '';
                      }
                    });
                  },
                  dropdownMenuEntries:
                      List.of(dropdownContexts.map((s) => DropdownMenuEntry(value: s, label: s))),
                ),
                const SizedBox(width: 5),
                IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        if (controller.text.isNotEmpty) {
                          widgets[controller.text] = FollowWidget(Follow.follow);
                        }
                      });
                    }),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OkCancel(make, 'Okay'),
        ]);
  }
}

class FollowWidget extends StatefulWidget {
  static final Map<double, Follow> i2follow = <double, Follow>{
    1: Follow.follow,
    -1: Follow.block,
  };
  static final Map<Follow, double> follow2i = <Follow, double>{
    Follow.follow: 1,
    Follow.block: -1,
  };

  late final ValueNotifier<Follow> followNotifier;

  FollowWidget(
    Follow follow, {
    super.key,
  }) : followNotifier = ValueNotifier<Follow>(follow);

  @override
  State<StatefulWidget> createState() => _FollowWidgetState();
}

class _FollowWidgetState extends State<FollowWidget> {
  @override
  Widget build(BuildContext context) {
    return Slider(
        value: FollowWidget.follow2i[widget.followNotifier.value]!,
        thumbColor: widget.followNotifier.value.color,
        min: -1.0,
        max: 1.0,
        divisions: 1,
        label: widget.followNotifier.value.label,
        onChanged: (x) {
          widget.followNotifier.value = FollowWidget.i2follow[x]!;
          setState(() {});
        });
  }
}
