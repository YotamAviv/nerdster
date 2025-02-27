import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:url_launcher/url_launcher.dart';

const Color linkColor = Colors.blueAccent;
final Color linkColorAlready = Colors.blue.shade900;
final Color linkColorDisabled = Colors.blue.shade200;
const TextStyle hintStyle = TextStyle(color: Colors.black26);
const TextStyle linkStyle = TextStyle(color: linkColor, decoration: TextDecoration.underline);

Future<void> myLaunchUrl(String url, BuildContext context) async {
  final Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    try {
      await launchUrl(uri);
    } catch (e) {
      await alertException(context, e);
    }
  } else {
    await alert('Bad URL?', 'Could not launch "$uri"', ['okay'], context);
  }
}
