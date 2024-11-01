import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color linkColor = Colors.blueAccent;
final Color linkColorAlready = Colors.blue.shade900;
const TextStyle linkStyle = TextStyle(color: linkColor, decoration: TextDecoration.underline);

// TODO: Add param context, show alert if can't
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
