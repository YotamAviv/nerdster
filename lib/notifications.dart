import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/menus.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/show_qr.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';
import 'package:nerdster/util_ui.dart';

// Goal: Test every kind of rejection / notification
// - Attempt to block your key.
// - Attempt to replace your key.
// - Attempt to block trusted key.
// - Attempt to trust blocked key.
// - Attempt to replace a replaced key.
// - TODO: Attempt to replace a blocked key.
// - Web-of-trust key equivalence rejected: Replaced key not in network. ('simpsons, degrees=2')
// - TO-DO: Web-of-trust key equivalence rejected: Replacing key not in network.
//   I don't think this can happen, not sure.. CONSIDER
// - TO-DO: Web-of-trust key equivalence rejected: Equivalent key already replaced.
//   I don't think this can happen, not sure.. CONSIDER

const Widget _space = SizedBox(height: 10);

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
    oneofusNet.addListener(listen);
    oneofusEquiv.addListener(listen);
    signInState.addListener(listen);
    super.initState();
  }

  @override
  void dispose() {
    oneofusNet.removeListener(listen);
    oneofusEquiv.removeListener(listen);
    signInState.removeListener(listen);
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

    List<MenuItemButton> notifications = <MenuItemButton>[];

    if (signInState.center != signInState.centerReset) {
      // Notfications I've decided against for now
      //       if (oneofusNet.network.containsKey(signInState.centerReset)) {
      //         MenuItemButton item = MenuItemButton(
      //             onPressed: () {
      //               showDialog<Json>(
      //                   context: context,
      //                   barrierDismissible: false,
      //                   builder: (BuildContext context) => Dialog(
      //                       child: Padding(
      //                           padding: const EdgeInsets.all(15),
      //                           child: OkCancel(() {
      //                             signInState.center = signInState.centerReset!;
      //                             Navigator.of(context).pop();
      //                           }, 'Reset'))));
      //             },
      //             child: Text(
      //                 '''You're viewing from the point of view of someone other than how you signed in'''));
      //         notifications.add(item);
      //       } else {
      //         MenuItemButton item = MenuItemButton(
      //             onPressed: () {},
      //             child: Text(
      //                 '''You're viewing from the point of view of someone other than how you signed in.
      // Furthermore, you're not even in this network, and so your contributions are not visible (You're not whitelisetd)'''));
      //         notifications.add(item);
      //       }
    } else {
      if (b(signInState.signedInDelegate)) {
        if (followNet.delegate2oneofus[signInState.signedInDelegate] != signInState.center) {
          MenuItemButton item = MenuItemButton(
              onPressed: () {
                alert('Delgate not associated with you', '''You're signed in with a Nerdster delgate key that isn't associated with you
You probably need to address this using your ONE-0F-US.NET phone app.''', ['Okay'], context);
              },
              child: const Text(
                  '''You're signed in with a Nerdster delgate key that isn't associated with you.'''));
          notifications.add(item);
        }
        // TODO: Check if delegate revoked
      }
    }

    Map<String, String> statementToken2reason = {
      ...oneofusNet.rejected,
      ...oneofusEquiv.rejected,
      ...oneofusEquiv.trustNonCanonical
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
                    content: StatementNotification(statement, reason),
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
      notifications.add(item);
    }

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
  final TrustStatement statement;
  final String reason;

  const StatementNotification(this.statement, this.reason, {super.key});

  @override
  Widget build(BuildContext context) {
    Json json = statement.json;
    String text = Jsonish.encoder.convert(keyLabels.show(json));

    Node? iNode = oneofusNet.network[statement.iToken];

    Node? subjectNode = oneofusNet.network[statement.subjectToken];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          // mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
                child: Linky(
                    '''A conflict was encountered during the trust network computation when processing the statement displayed to the right:

This doesn't necessarily require you to do anything. For example if a key you trust is blocked by another key, then it matters to you, and you'll see a notification, but when the owner of that key signs in, he'll see a notification that a key is blocking his key, and so sorting this should be more on him than on you.
That said, even in that situation, it may be the case that that guy never checks his notifications, and so maybe pick up the slack for him.''')),
            Text(text,
                style: GoogleFonts.courierPrime(
                    fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black))
          ],
        ),
        _space,
        Flexible(child: Linky('''Tactics for addressing this:
- If you think you know the individuals involved, get in touch with them, figure it out, and get it straightened out.
- Consider browsing as others. You'll see the notifications they would see, and this may shed light on the situation.
- Email conflict-help@nerdtser.org. Include the link from the "menu => /etc => Generate link for current view".''')),
        _space,
        Text('''Trust paths to the statement's signing key:'''),
        TrustRows(iNode),
        _space,
        Text('''Trust paths to the key the statements is trying to ${statement.verb.label}:'''),
        TrustRows(subjectNode),
        _space,
        Flexible(
            child: Linky('''This app obviously does not know which actual people posses which keys.
It has labled the keys in the paths above by best guess monikers provided by your network; but they could be wrong.
You can click on the keys on those paths to see their QR codes, and if appropriate, use your ONE-OF-US phone app and block.''')),
        _space,
      ],
    );
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
      onTap: () {
        ShowQr(encoder.convert(keyJson)).show(context);
      },
      child: Text(
        display,
        style: linkStyle,
      ),
    );
  }
}
