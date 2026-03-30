import 'package:flutter/cupertino.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:nerdster/ui/util_ui.dart';

const kManUrl = 'https://one-of-us.net/man';

class Linky extends StatelessWidget {
  final String text;
  const Linky(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return SelectableLinkify(
      onOpen: (LinkableElement link) async {
        final String url = link.text.startsWith('manual') ? kManUrl : link.url;
        await myLaunchUrl(url);
      },
      // DEFER: style: TextStyle(fontFamily: 'Courier'),
      text: text,
    );
  }
}
