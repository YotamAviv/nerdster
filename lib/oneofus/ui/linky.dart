import 'package:flutter/cupertino.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

const kManUrl = 'https://one-of-us.net/man';

class Linky extends StatelessWidget {
  final String text;
  const Linky(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return SelectableLinkify(
      onOpen: (LinkableElement link) async {
        Uri uri;
        if (link.text.startsWith('manual')) {
          uri = Uri.parse(kManUrl);
        } else {
          uri = Uri.parse(link.url);
        }
        if (!await launchUrl(uri)) {
          throw Exception('Could not launch ${link.url}');
        }
      },
      // DEFER: style: TextStyle(fontFamily: 'Courier'),
      text: text,
    );
  }
}
