import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/menus.dart';
import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';
import 'package:nerdster/util_ui.dart';

import 'oneofus/json_display.dart';

class NotificationsMenu extends StatefulWidget {
  static final NotificationsMenu _singleton = NotificationsMenu._internal();
  factory NotificationsMenu() {
    return _singleton;
  }
  const NotificationsMenu._internal();

  @override
  State<StatefulWidget> createState() => _NotificationsMenuState();
}

class _NotificationsMenuState extends State<NotificationsMenu> {
  @override
  void initState() {
    contentBase.addListener(listen);
    followNet.addListener(listen);
    signInState.addListener(listen);
    Notifications().addListener(listen);
    super.initState();
  }

  @override
  void dispose() {
    contentBase.removeListener(listen);
    followNet.removeListener(listen);
    signInState.removeListener(listen);
    Notifications().removeListener(listen);
    super.dispose();
  }

  void listen() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!Comp.compsReady([oneofusNet, followNet, oneofusEquiv])) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        listen();
      });
      return const Text('Loading..');
    }

    List<MenuItemButton> items = <MenuItemButton>[];

    if (b(signInState.signedInDelegate) &&
        !b(followNet.delegate2oneofus[signInState.signedInDelegate])) {
      MenuItemButton item = MenuItemButton(
          onPressed: () {
            alert(
                '''Your Nerdster delgate isn't in this network''',
                '''You're signed in with a Nerdster delgate key that isn't in the network you're viewing, and so your own content will not be visible.''',
                ['Okay'],
                context);
          },
          child: const Text('''Your Nerdster delgate isn't in this network.'''));
      items.add(item);
    }
    // TODO: Check if delegate revoked

    Map<String, String> statementToken2reason = {
      ...notifications.rejected,
      ...notifications.warned,
      // corrupt tokens are key tokens, not statement tokens ...notifications.corrupted,
    };
    for (MapEntry<String, String> e in statementToken2reason.entries) {
      TrustStatement statement = TrustStatement.find(e.key)!;
      String reason = e.value;
      MenuItemButton item = MenuItemButton(
          onPressed: () {
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                    title: Text(reason),
                    content: StatementNotification(statement!, reason),
                    actions: [
                      OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Okay'))
                    ]);
              },
            );
          },
          child: Text(reason));
      items.add(item);
    }

    for (MapEntry<String, (String, String?)> e in notifications.corrupted.entries) {
      String iToken = e.key;
      Jsonish? iKey = Jsonish.find(iToken);
      String? iLable = keyLabels.labelKey(e.key);
      String error = e.value.$1;
      String? details = e.value.$2;
      MenuItemButton item = MenuItemButton(
          onPressed: () {
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                    title: Text(error),
                    // TODO: Better than this...
                    content: SingleChildScrollView(
                      child: Column(
                        children: [
                          Text('''iToken: $iToken, iKey: $iKey, iLable: $iLable '''),
                          if (b(details)) Text(details!),
                        ],
                      ),
                    ),
                    actions: [
                      OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Okay'))
                    ]);
              },
            );
          },
          child: Text(error));
      items.add(item);
    }

    Color? color = items.isNotEmpty ? Colors.red : null;
    return SubmenuButton(
        menuChildren: items,
        child: Row(
          children: [
            Icon(Icons.notifications, color: color),
            iconSpacer,
            Text('Notifications', style: TextStyle(color: color)),
          ],
        ));
  }
}

class StatementNotification extends StatelessWidget {
  final TrustStatement statement;
  final String reason;

  const StatementNotification(this.statement, this.reason, {super.key});

  static const Widget _space = SizedBox(height: 10);

  @override
  Widget build(BuildContext context) {
    Node? iNode = oneofusNet.network[statement.iToken];
    Node? subjectNode = oneofusNet.network[statement.subjectToken];

    Size whole = MediaQuery.of(context).size;
    Size big = Size(whole.width * 0.9, whole.height * 0.9);

    return SizedBox.fromSize(
        size: big,
        child: ListView(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: Linky(
                        '''A conflict was encountered during the trust network computation when processing the statement displayed to the right:

This doesn't necessarily require you to do anything. For example if a key you trust is blocked by another key, then it should matter to you, and you'll see a notification, but when the owner of that key signs in, he'll see a notification that a key is blocking his own key, and so sorting this out should be more on him than on you.
That said, even in that situation, it may be the case that that guy never checks his notifications, and so maybe pick up the slack for him.''')),
                SizedBox(
                    width: big.width / 2,
                    height: big.height / 2,
                    child: JsonDisplay(statement.json))
              ],
            ),
            _space,
            Linky('''Tactics for addressing this:
- If you think you know the individuals involved, get in touch with them, figure it out, and get it straightened out by clearing trusts or blocks or stating new ones.
- Try browsing as others (different PoV). You'll see the notifications they would see, and this may shed light on the situation.
- Email conflict-help@nerdtser.org. Include the link from the "menu => /etc => Generate link for current view".'''),
            _space,
            Text('''Trust paths to the statement's signing key:'''),
            TrustRows(iNode),
            _space,
            Text('''Trust paths to the key the statements is trying to ${statement.verb.label}:'''),
            TrustRows(subjectNode),
            _space,
            Linky('''This app obviously does not know which actual people posses which keys.
It has labled the keys in the paths above by best guess monikers provided by your network, but those could be wrong.
You can click on the keys on those paths to see their QR codes, and if appropriate, use your ONE-OF-US phone app and block.'''),
            _space,
          ],
        ));
  }
}

class TrustRows extends StatelessWidget {
  final Node? node;
  const TrustRows(this.node, {super.key});

  @override
  Widget build(BuildContext context) {
    if (!b(node)) return Text('Unknown, untrusted, unsure... ;(');

    // Special case for me. no paths.
    if (node!.token == signInState.center) return Text('- Me');

    List<Row> rows = <Row>[];
    for (List<Trust> path in node!.paths) {
      List<Widget> monikers = <Widget>[];
      monikers.add(Text('- Me'));
      for (Trust trust in path.sublist(1)) {
        TrustStatement statement = TrustStatement.find(trust.statementToken)!;
        String moniker;
        if (statement.verb == TrustVerb.trust) {
          moniker = statement.moniker!;
        } else {
          assert(statement.verb == TrustVerb.replace);
          moniker = '(replaced)';
        }
        monikers.add(Text(' --"$moniker"-> '));
        monikers.add(NameKeyWidget(keyLabels.labelKey(statement.subjectToken)!, statement.subject));
      }
      rows.add(Row(children: monikers));
    }

    return Column(children: rows);
  }
}

class NameKeyWidget extends StatelessWidget {
  final String display;
  final Json keyJson;

  const NameKeyWidget(this.display, this.keyJson, {super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => JsonQrDisplay(keyJson).show(context),
      child: Text(
        display,
        style: linkStyle,
      ),
    );
  }
}
