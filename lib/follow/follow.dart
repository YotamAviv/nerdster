import 'package:flutter/material.dart';
import 'package:nerdster/content/content_base.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/ui/lower_case_text_formatter.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

/// Prep towards Network layers
/// Motivation:
///   Censor, Dis, comment on a statement...
///   Can a different nerd censor my follow or block? Comment on it? (I'd rather not)
///   The answer is that the Nerdster follows network is a layer above the Nerdster censor and dis.
/// [ContentBase] should use the Nerdster follows network where it was using the [NetBase] network before.
///
/// The layers should be:
/// - OneofusNet: oneofus / fetcher (async, and sort of same as fetcher): trusted keys only, rejected and conflict statements identified
///   - revokedAtToken, revokedAtTime on these fetchers
///   - do we need the paths? Yes, I think so.
///
/// - OneofusCanon: canonical (WOT): statements made by equivalents appear as if made by canonical.
///   - NOTE: Re: 'I'. Don't change the statements, but consider that their 'I' may not be accurate.
///     Will at least require removing asserts.
///   - no more revokedAt. That's in the previous layer.
///
/// OneofusWOT could be a consumer of OneofusNet
///
/// - DelegateNet: delegate (async): statements made by delegates appear as if made by oneofus canonical
///   - (Try and include delegate domain)
///
/// - follow: reduced to include only who you follow
///
/// - censored: reduced ..
///
/// Observe / listen .. dirty/ready
///
/// Consumers of these [Network]s.
/// - NetNode
///   relies on rejected and conflict statement knowledge
///
/// - NetTreeNode
///   relies on rejected and conflict statement knowledge
/// - KeyLabels
///
///
/// ISSUES with just LinkedHashMap<token, distinct statements>
/// - NetTree: needs revoked at time (known by Fetcher)
/// - dump: needs all statements including non-distinct and cleared
/// - names, labels.. still thinking...
///
/// Interim thought: Just do it from FollowNet (which I have) onwards

enum Follow {
  follow('Follow', Colors.green, 1),
  block('Block', Colors.red, -1);

  final String label;
  final Color color;
  final int intValue;
  const Follow(this.label, this.color, this.intValue);
}

Future<Jsonish?> follow(String token, BuildContext context) async {
  if (await checkSignedIn(context) != true) {
    return null;
  }
  ContentStatement? priorStatement;
  for (ContentStatement s in followNet.getStatements(signInState.center)) {
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
    Jsonish statement = await followNet.insert(json);
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
            child: Padding(
          padding: const EdgeInsets.all(15),
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
    dropdownContexts.addAll(followNet.most);
    dropdownContexts.addAll(['social', 'nerd']);
    dropdownContexts.removeWhere((c) => widgets.keys.contains(c));

    List<Row> rows = <Row>[];
    for (MapEntry e in widgets.entries) {
      Row row = Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        BoxLabel(e.key),
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
              child: Column(
                children: rows,
              )),
          const SizedBox(height: 5),
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Add a follow context: '),
                DropdownMenu<String>(
                  controller: controller,
                  inputFormatters: [LowerCaseTextFormatter()],
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

class BoxLabel extends StatelessWidget {
  final String label;
  const BoxLabel(
    this.label, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      child: Text(label),
    );
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
        min: -1,
        max: 1,
        divisions: 1,
        label: widget.followNotifier.value.label,
        onChanged: (x) {
          widget.followNotifier.value = FollowWidget.i2follow[x]!;
          setState(() {});
        });
  }
}
