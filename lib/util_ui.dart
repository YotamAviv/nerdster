import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const linkStyle = TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline);

Future<void> myLaunchUrl(String url) async {
  final Uri uri = Uri.parse(url);
  /* BAD
  if (!await launchUrl(url)) {
    print('Exception');
    // Happens every time. Ignore: throw Exception('Could not launch $_url');
  }
  */
  if (await canLaunchUrl(uri)) {
    try {
      await launchUrl(uri);
    } catch(e) {
      print(e);
    }
  } else {
    print ('Could not launch $uri');
  }
}
