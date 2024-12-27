import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/menus.dart';
import 'package:nerdster/net/key_lables.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

// Goal: Test every kind of rejection / notification
// - Attempt to block your key.
// - A trusted key was blocked.
// - A key $blockerPathLength degrees away attempted to block a key $blockeePathLength degrees away.
// - Attempt to replace your key.
// - A key $replacerPathLength degrees away attempted to replace a key $replaceePathLength degrees away.
// - Attempt to replace a replaced key.
// - TODO: Attempt to replace a blocked key.
// - Attempt to trust blocked key.
// - Web-of-trust key equivalence rejected: Replaced key not in network. ('simpsons, degrees=2')
// - TO-DO: Web-of-trust key equivalence rejected: Replacing key not in network.
//   I don't think this can happen, not sure.. CONSIDER
// - TO-DO: Web-of-trust key equivalence rejected: Equivalent key already replaced.
//   I don't think this can happen, not sure.. CONSIDER

// TODO: Challenge is that 'I' or 'subject' might not be in network, and so hard to show:
// - paths
// - label

// As Trust1 does BFS, it can encounter conflicts, and at the time, it does know:
// - degree
// - in case 


printStatement(String statementToken) {
  TrustStatement statement = TrustStatement.find(statementToken)!;
  var nice = keyLabels.show(statement.json);
  String string = encoder.convert(nice);
  print(string);
}

class NotificationsMenu extends StatefulWidget {
  const NotificationsMenu({super.key});

  @override
  State<StatefulWidget> createState() {
    return _NotificationsMenuState();
  }
}

class _NotificationsMenuState extends State<NotificationsMenu> {
  @override
  void initState() {
    print('notifications.initState(..)');
    oneofusNet.addListener(listen);
    oneofusEquiv.addListener(listen);
    super.initState();
  }

  @override
  void dispose() {
    oneofusNet.removeListener(listen);
    oneofusEquiv.removeListener(listen);
    super.dispose();
  }

  void listen() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!Comp.compsReady([oneofusNet, oneofusEquiv])) {
      // I'm not confident about this.
      // print('loading..');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        listen();
      });
      return const Text('Loading..');
    }
    print('notifications.build(${Comp.compsReady([oneofusNet, oneofusEquiv])})');
    List<Widget> notifications = <Widget>[];
    Map<String, String> all = {
      ...oneofusNet.rejected,
      ...oneofusEquiv.rejected,
      ...oneofusEquiv.trustNonCanonical
    };
    for (MapEntry<String, String> e in all.entries) {
      Jsonish statement = Jsonish.find(e.key)!;
      String reason = e.value;
      MenuItemButton x = MenuItemButton(
          onPressed: () {
            String text = Jsonish.encoder.convert(KeyLabels().show(statement.json));
            alert(reason, text, ['Okay'], context);
                // showDialog(
                //     context: context,
                //     barrierDismissible: true,
                //     builder: (BuildContext context) => Dialog(
                //         child: SizedBox(
                //             width: (MediaQuery.of(context).size).width / 2,
                //             child: StatementNotification(statement, reason))))
              },
          child: Text(reason));
      notifications.add(x);
    }

    print('notifications.length=${notifications.length}');

    return SubmenuButton(
        menuChildren: notifications,
        child: const Row(
          children: [
            Icon(Icons.notifications),
            iconSpacer,
            Text('Notifications'),
          ],
        ));
  }
}

class StatementNotification extends StatelessWidget {
  final Jsonish statement;
  final String reason;

  const StatementNotification(this.statement, this.reason, {super.key});

  @override
  Widget build(BuildContext context) {
    Json json = statement.json;
    String subject = statement.token;
    String text = Jsonish.encoder.convert(KeyLabels().show(json));

    return Text(text,
        style: GoogleFonts.courierPrime(
            fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black));
  }
}
