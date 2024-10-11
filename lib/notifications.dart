import 'package:flutter/material.dart';
import 'package:nerdster/net/key_lables.dart';
import 'package:nerdster/net/oneofus_net.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/net/oneofus_equiv.dart';

enum NotificationType {
  youTrustEquivalentKeyDirectly,
  attemptToBlockYourKey,
  attemptToReplaceYourKey,
  farKeyBlockCloseKeyAttempt,
}

/// TODO: a lot...
/// - Get these right, consider all the cases, currently listed in NerdBase
/// - Describe the condition, the options for dealing with the condition,
///   and enable a way to do it, probably QR code to phone app.
///
/// Make it easier: If the bad guy is already not in network, then skip the notification. Do this in early, like in Trust1.
class NotificationsMenu extends StatefulWidget {
  const NotificationsMenu({super.key});

  @override
  State<StatefulWidget> createState() {
    return _NotificationsMenuState();
  }
}

class _NotificationsMenuState extends State<NotificationsMenu> {
  _NotificationsMenuState() {
    OneofusEquiv().addListener(listen);
  }

  void listen() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> notifications = <Widget>[];
    for (MapEntry<String, String> e in OneofusNet().rejected.entries) {
      Jsonish statement = Jsonish.find(e.key)!;
      String reason = e.value;
      RejectedNotification n = RejectedNotification(statement, reason);
      notifications.add(n);
    }
    for (MapEntry<String, String> e in OneofusEquiv().trustNonCanonical.entries) {
      Jsonish statement = Jsonish.find(e.key)!;
      String reason = e.value;
      TrustNonCanonicalNotification n = TrustNonCanonicalNotification(statement, reason);
      notifications.add(n);
    }

    return SubmenuButton(menuChildren: notifications, child: const Text('Notifications'));
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

    // Text(Jsonish.encoder.convert(OneofusEquiv().show(json)));
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

    // Text(Jsonish.encoder.convert(OneofusEquiv().show(json)));
  }
}
