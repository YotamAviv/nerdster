import 'package:flutter/cupertino.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rtfm_anchors.dart';

class Linky extends StatelessWidget {
  final String text;
  const Linky(
    this.text, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableLinkify(
      onOpen: (LinkableElement link) async {
        Uri uri;
        if (link.text.startsWith('RTFM#')) {
          String url = kRtfmAnchors[link.url] ?? kOneofusUserManualUrl;
          uri = Uri.parse(url);
        } else {
          uri = Uri.parse(link.url);
        }
        if (!await launchUrl(uri)) {
          throw Exception('Could not launch ${link.url}');
        }
      },
      text: text,
    );
  }
}
