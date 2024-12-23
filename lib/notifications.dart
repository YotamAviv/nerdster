import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/menus.dart';
import 'package:nerdster/net/key_lables.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';


/// TODO: a lot, see [OneofusNet]


// Goal: Test every kind of rejection / notification
// - TODO: Attempt to block your key.
// - A trusted key was blocked. (3'rd level block removes 1'st level trust)
// - TODO: A key $blockerPathLength degrees away attempted to block a key $blockeePathLength degrees away.
// - Attempt to replace your key. ('simpsons, degrees=3')
// - TODO: A key $replacerPathLength degrees away attempted to replace a key $replaceePathLength degrees away.
// - TODO: Attempt to replace a replaced key.
// - TODO: Attempt to replace a blocked key.
// - TODO: Attempt to trust blocked key.
// - Web-of-trust key equivalence rejected: Replaced key not in network. ('simpsons, degrees=2')
// - TODO: Web-of-trust key equivalence rejected: Replacing key not in network.
// - TODO: Web-of-trust key equivalence rejected: Equivalent key already replaced.


// TODO: Challenge is that I or subject might not be in network, and so hard to show:
// - paths
// - label
// Helpers, WIP..
dumpStatement(String statementToken) {
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
    for (MapEntry<String, String> e in oneofusNet.rejected.entries) {
      Jsonish statement = Jsonish.find(e.key)!;
      String reason = e.value;
      RejectedNotification n = RejectedNotification(statement, reason);
      notifications.add(n);
    }
    for (MapEntry<String, String> e in oneofusEquiv.trustNonCanonical.entries) {
      Jsonish statement = Jsonish.find(e.key)!;
      String reason = e.value;
      TrustNonCanonicalNotification n = TrustNonCanonicalNotification(statement, reason);
      notifications.add(n);
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

class RejectedNotification extends StatelessWidget {
  final Jsonish statement;
  final String reason;

  const RejectedNotification(this.statement, this.reason, {super.key});

  @override
  Widget build(BuildContext context) {
    Json json = statement.json;
    String subject = statement.token;

    return
        // InkWell(
        //     onTap: (() => {}),
        //     child: Tooltip(
        //         richMessage: WidgetSpan(child: qrTooltip),
        //         child: Text('{JS}',
        //             style: GoogleFonts.courierPrime(
        //                 fontWeight: FontWeight.w700,
        //                 fontSize: 12,
        //                 color: Colors.black)))),
//    )
        Tooltip(
      message: Jsonish.encoder.convert(KeyLabels().show(json)),
      child: Text(reason),
    );

    // Text(reason);

    // Text(Jsonish.encoder.convert(oneofusEquiv.show(json)));
  }
}

class TrustNonCanonicalNotification extends StatelessWidget {
  final Jsonish statement;
  final String reason;

  const TrustNonCanonicalNotification(this.statement, this.reason, {super.key});

  @override
  Widget build(BuildContext context) {
    Json json = statement.json;

    return
        // InkWell(
        //     onTap: (() => {}),
        //     child: Tooltip(
        //         richMessage: WidgetSpan(child: qrTooltip),
        //         child: Text('{JS}',
        //             style: GoogleFonts.courierPrime(
        //                 fontWeight: FontWeight.w700,
        //                 fontSize: 12,
        //                 color: Colors.black)))),
//    )
        Tooltip(
      message: Jsonish.encoder.convert(KeyLabels().show(json)),
      child: Text(reason),
    );

    // Text(reason);

    // Text(Jsonish.encoder.convert(oneofusEquiv.show(json)));
  }
}
